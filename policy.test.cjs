const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const registry=require('./blade-device-registry.json');
function load(file,deps){const module={exports:{}};vm.runInNewContext(fs.readFileSync(__dirname+'/'+file,'utf8'),{module,URL,require:n=>{if(n in deps)return deps[n];throw Error('Unexpected dependency '+n)}});return module.exports;}
const policy=load('device-exclusion-universal.cjs',{'./blade-device-registry.json':registry});
const native=load('native-exclusion-universal.cjs',{'node:path':require('node:path'),'./openblade-device-exclusion.cjs':policy});
test('every reviewed Blade ID is excluded',()=>{assert.equal(registry.devices.length,40);for(const d of registry.devices)assert.equal(policy.blockedDevice({vendorId:d.vendorId,productId:d.productId}),true)});
test('Pro Click V2 remains available',()=>assert.equal(policy.blockedDevice({vendorId:0x1532,productId:0x00d1}),false));
test('unresolved products are not guessed as Blades',()=>{for(const productId of registry.unresolvedProductIds)assert.equal(policy.blockedDevice({vendorId:0x1532,productId}),false)});
test('other vendors are never matched by product ID alone',()=>assert.equal(policy.blockedDevice({vendorId:0x1234,productId:0x02e0}),false));
test('Blade sender is denied before native forwarding',()=>assert.throws(()=>native.assertAllowed('electronAction',{senderFrame:{url:'https://apps.razer.com/synapse/products/736/ui/'}},{action:'StartService'}),e=>e.code==='OPENBLADE_NATIVE_DEVICE_EXCLUDED'));
test('mouse and shared native routes remain available',()=>{for(const url of ['https://apps.razer.com/synapse/products/209/ui/','https://apps.razer.com/background-manager/'])assert.doesNotThrow(()=>native.assertAllowed('electronAction',{senderFrame:{url}},{action:'StartService'}))});

// Offline snapshot of every officially supported model in the pinned core catalog.
const coreCatalog = require('./fixtures/openblade-models.json');
test('pinned OpenBlade catalog has complete reviewed registry and guide coverage', () => {
  assert.equal(coreCatalog.models.length, 19);
  assert.equal(new Set(coreCatalog.models.map(m => m.modelNumber)).size, 19);
  assert.equal(new Set(coreCatalog.models.map(m => m.vendorId + ':' + m.productId)).size, 19);
  for (const {modelNumber, vendorId, productId} of coreCatalog.models) {
    assert.equal(vendorId, 0x1532);
    assert(registry.devices.some(d => d.vendorId === vendorId && d.productId === productId), modelNumber);
    for (const guide of ['README.md', 'README.ru-RU.md', 'README.zh-CN.md']) {
      const identity = '1532:' + productId.toString(16).padStart(4, '0').toUpperCase();
      assert(fs.readFileSync(__dirname + '/' + guide, 'utf8').includes('| ' + modelNumber + ' | `' + identity + '` |'), guide + ': ' + modelNumber);
    }
  }
});
for (const {modelNumber: model, productId} of coreCatalog.models) {
  test(`${model}: discovery, HID paths and direct opens exclude the laptop only`, () => {
    const hex = productId.toString(16).padStart(4, '0');
    const blade = {vendorId: 0x1532, productId};
    const peripheral = {vendorId: 0x1532, productId: 0x00d1};
    const otherVendor = {vendorId: 0x1234, productId};
    assert(registry.devices.some(d => d.vendorId === blade.vendorId && d.productId === productId));
    assert(!registry.unresolvedProductIds.includes(productId));
    assert.equal(policy.blockedDevice(blade), true);
    assert.equal(policy.blockedDevice({vendorId: '0x1532', productId: '0x' + hex}), true);
    assert.deepEqual(Array.from(policy.visibleDevices([blade, peripheral, otherVendor])), [peripheral, otherVendor]);
    for (const mi of ['00', '01', '02', '03']) {
      const devicePath = `\\\\?\\HID#VID_1532&PID_${hex.toUpperCase()}&MI_${mi}#synthetic`;
      assert.equal(policy.blockedPath(devicePath), true);
      for (const field of ['path', 'devicePath', 'deviceId']) assert.equal(policy.blockedDevice({[field]: devicePath}), true);
      assert.throws(() => policy.rejectOpen([devicePath]), e => e.code === 'OPENBLADE_DEVICE_EXCLUDED');
    }
    assert.equal(policy.blockedPath(`USB\\VID_1532&PID_${hex}\\synthetic`), true);
    assert.equal(policy.blockedPath(`\\\\?\\hid#vid_1532&pid_${hex}0#synthetic`), false);
    assert.equal(policy.blockedPath(`\\\\?\\hid#vid_1234&pid_${hex}#synthetic`), false);
    assert.throws(() => policy.rejectOpen([0x1532, productId]), e => e.code === 'OPENBLADE_DEVICE_EXCLUDED');
    assert.doesNotThrow(() => policy.rejectOpen([0x1234, productId]));
    assert.doesNotThrow(() => policy.rejectOpen([peripheral.vendorId, peripheral.productId]));
  });

  test(`${model}: native product, mapping and lifecycle routes exclude the laptop`, () => {
    const excluded = e => e.code === 'OPENBLADE_NATIVE_DEVICE_EXCLUDED';
    const shared = {senderFrame: {url: 'https://apps.razer.com/background-manager/'}};
    for (const prefix of ['/products/', '/synapse/products/']) {
      const url = `https://apps.razer.com${prefix}${productId}/ui/`;
      for (const event of [{senderFrame: {url}}, {sender: {getURL: () => url}}]) {
        for (const route of ['ffiPreload', 'ffiPreloadAsync', 'ffiSubPreloadAsync', 'mappingEngineAction', 'simpleServiceAction', 'lightingDriver', 'electronAction']) {
          assert.throws(() => native.assertAllowed(route, event, {action: 'StartService'}), excluded);
        }
      }
    }
    const blade = {vendorId: 0x1532, productId};
    for (const field of ['usbDevice', 'device']) {
      assert.throws(() => native.assertAllowed('mappingEngineAction', shared, {payload: {[field]: blade}}), excluded);
      assert.doesNotThrow(() => native.assertAllowed('mappingEngineAction', shared, {payload: {[field]: {...blade, vendorId: 0x1234}}}));
    }
    const deviceContainerId = 'a0000000-0000-0000-0000-' + productId.toString().padStart(12, '0');
    policy.observeDevice({...blade, deviceContainerId});
    for (const route of ['ffiPreload', 'ffiPreloadAsync', 'ffiSubPreloadAsync']) {
      for (const action of ['SetAPIToCallWhenExitDevice', 'SetAPIToCallWhenShutdown', 'SetAPIToCallWhenSuspend']) {
        for (const payload of [blade, {productId, deviceContainerId}]) {
          assert.throws(() => native.assertAllowed(route, shared, {action, payload}), excluded);
        }
        assert.doesNotThrow(() => native.assertAllowed(route, shared, {action, payload: {...blade, vendorId: 0x1234, deviceContainerId}}));
        assert.doesNotThrow(() => native.assertAllowed(route, shared, {action, payload: {vendorId: 0x1532, productId: 0x00d1}}));
      }
    }
  });
}
