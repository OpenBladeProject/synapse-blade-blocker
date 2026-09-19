'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
function helper(){const module={exports:{}};vm.runInNewContext(fs.readFileSync(__dirname+'/patched-blades/openblade-device-exclusion.cjs','utf8'),{module,require(name){assert.equal(name,'./blade-device-registry.json');return require('./blade-device-registry.json');}},{timeout:1000});return module.exports;}
const guid='A0000000-0000-0000-0000-000000000736';
const blade={vendorId:5426,productId:736,deviceContainerId:guid};
test('successful discovery learns exact container before hiding Blade',()=>{const h=helper();assert.equal(h.visibleDevices([blade]).length,0);assert.equal(h.observedBladeDevice({productId:'736',deviceContainerId:'{'+guid.toLowerCase()+'}'}),true);});
test('failed enumeration does not create identity evidence',()=>{const h=helper();h.visibleDevices([blade],false);assert.equal(h.observedBladeDevice(blade),false);});
test('other vendor and product/container mismatches remain unclassified',()=>{const h=helper();h.observeDevice(blade);for(const d of [{...blade,vendorId:1111},{...blade,productId:737},{...blade,deviceContainerId:'B0000000-0000-0000-0000-000000000736'}])assert.equal(h.observedBladeDevice(d),false);});
test('conflicting vendor observations invalidate identity permanently',()=>{const h=helper();h.observeDevice(blade);h.observeDevice({...blade,vendorId:1111});h.observeDevice(blade);assert.equal(h.observedBladeDevice({productId:736,deviceContainerId:guid}),false);});
test('invalid and zero containers are never retained',()=>{const h=helper();for(const deviceContainerId of ['',null,'fixture','00000000-0000-0000-0000-000000000000','{'+guid,guid+'}']){const d={...blade,deviceContainerId};h.observeDevice(d);assert.equal(h.observedBladeDevice(d),false);}});
test('observation cap preserves old evidence without unbounded growth',()=>{const h=helper();for(let i=0;i<257;i++)h.observeDevice({...blade,deviceContainerId:'C0000000-0000-0000-0000-'+i.toString(16).padStart(12,'0')});assert.equal(h.observedBladeDevice({...blade,deviceContainerId:'C0000000-0000-0000-0000-000000000000'}),true);assert.equal(h.observedBladeDevice({...blade,deviceContainerId:'C0000000-0000-0000-0000-000000000100'}),false);});
test('product-only and renderer-shaped strings do not establish observation',()=>{const h=helper();h.observeDevice({productId:736,deviceContainerId:guid});assert.equal(h.observedBladeDevice({productId:736,deviceContainerId:guid}),false);});

test('shared Windows internal-device sentinel never establishes unique identity',()=>{
 const h=helper();
 for(const deviceContainerId of ['{00000000-0000-0000-FFFF-FFFFFFFFFFFF}','00000000-0000-0000-ffff-ffffffffffff']){
  const d={...blade,deviceContainerId};h.observeDevice(d);
  assert.equal(h.observedBladeDevice({productId:736,deviceContainerId}),false);
  assert.equal(h.visibleDevices([d]).length,0);
 }
});
test('sentinel observations do not consume the bounded identity budget',()=>{
 const h=helper();h.observeDevice({...blade,deviceContainerId:'{00000000-0000-0000-FFFF-FFFFFFFFFFFF}'});
 for(let i=0;i<256;i++)h.observeDevice({...blade,deviceContainerId:'D0000000-0000-0000-0000-'+i.toString(16).padStart(12,'0')});
 assert.equal(h.observedBladeDevice({...blade,deviceContainerId:'D0000000-0000-0000-0000-0000000000ff'}),true);
});
