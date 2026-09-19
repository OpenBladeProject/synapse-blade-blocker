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
