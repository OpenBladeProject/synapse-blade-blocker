'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path'),events=require('node:events'),util=require('node:util'),crypto=require('node:crypto');
const root=require('./test-root.cjs'),helper=require(require('./test-root.cjs')+'/patched-blades/openblade-device-exclusion.cjs');
const blade={vendorId:5426,productId:736,path:'\\\\?\\hid#vid_1532&pid_02e0&mi_02#synthetic'};
const peripheral={vendorId:5426,productId:153,path:'\\\\?\\hid#vid_1532&pid_0099#synthetic'};
const otherVendor={vendorId:1111,productId:736,path:'\\\\?\\hid#vid_0457&pid_02e0#synthetic'};
function load(name,modules,global={}){const module={exports:{}};const context={module,exports:module.exports,global,console,Buffer,process:{nextTick:process.nextTick},require(id){if(Object.hasOwn(modules,id))return modules[id];throw Error('Forbidden real dependency: '+id);}};vm.runInNewContext(fs.readFileSync(path.join(root,'patched-blades',name),'utf8'),context,{filename:name,timeout:1000});return module.exports;}
function usbFixture(error=null,devices=[blade,peripheral,otherVendor]){let added,removed;const calls=[],emitted=[];class Emitter extends events.EventEmitter{emit(...args){emitted.push(args);return super.emit(...args);}}
 const detection={find(...args){calls.push(args.slice(0,-1));args.at(-1)(error,devices);},registerAdded(fn){added=fn;},registerRemoved(fn){removed=fn;},startMonitoring(){},stopMonitoring(){}};
 const usb=load('node_modules/rz-usb-detect/index.js',{'../../openblade-device-exclusion.cjs':helper,'./package.json':{name:'rz-usb-detect',version:'test'},bindings:name=>{assert.equal(name,'detection.node');return detection;},eventemitter2:{EventEmitter2:Emitter}});
 return {usb,calls,emitted,add:d=>added(d),remove:d=>removed(d)};
}
function hidFixture(){const opens=[];let bindingLoads=0;function NativeHid(...args){opens.push(args);}NativeHid.prototype.close=function(){};NativeHid.prototype.read=function(){};NativeHid.prototype.sendFeatureReport=function(data){return data.length;};const binding={HID:NativeHid,devices(){return [blade,peripheral,otherVendor];},setTimerResolution(){},clearTimerResolution(){}};
 const hid=load('node_modules/node-rz-hid/nodehid.js',{'../../openblade-device-exclusion.cjs':helper,os:{platform:()=> 'win32'},events,util,'./package.json':{version:'test'},bindings:name=>{assert.equal(name,'HID.node');bindingLoads++;return binding;}});return {hid,opens,loads:()=>bindingLoads};}
test('exact numeric VID/PID filtering preserves peripheral and other vendor',()=>{assert.equal(helper.blockedDevice(blade),true);assert.equal(helper.blockedDevice(peripheral),false);assert.equal(helper.blockedDevice(otherVendor),false);});
test('all target interfaces and case variants blocked, near-match PID retained',()=>{for(const mi of ['00','01','02','03'])assert.equal(helper.blockedPath(`\\\\?\\HID#VID_1532&PID_02E0&MI_${mi}#synthetic`),true);assert.equal(helper.blockedPath('USB\\VID_1532&PID_02E0\\synthetic'),true);assert.equal(helper.blockedPath('\\\\?\\hid#vid_1532&pid_02e00#synthetic'),false);});
test('string ID forms and device-path fallback handled',()=>{assert.equal(helper.blockedDevice({vendorId:'5426',productId:'736'}),true);assert.equal(helper.blockedDevice({vendorId:'0x1532',productId:'0x02e0'}),true);assert.equal(helper.blockedDevice({devicePath:blade.path}),true);assert.equal(helper.blockedDevice({deviceId:blade.path}),true);});
test('USB promise enumeration filters target only',async()=>{const {usb}=usbFixture();const list=await usb.find();assert.equal(list.length,2);assert.equal(list[0],peripheral);assert.equal(list[1],otherVendor);});
test('USB callback and promise see same filtered result',async()=>{const {usb,calls}=usbFixture();let callbackResult;const promiseResult=await usb.find(5426,736,(err,list)=>{assert.equal(err,null);callbackResult=list;});assert.equal(callbackResult,promiseResult);assert.deepEqual(Array.from(calls[0]),[5426,736]);assert.equal(promiseResult.includes(blade),false);});
test('USB optional callback forms remain supported',async()=>{for(const withVid of [false,true]){const {usb}=usbFixture();let called=false;const callback=(err,list)=>{called=true;assert.equal(list.length,2);};await (withVid?usb.find(5426,callback):usb.find(callback));assert.equal(called,true);}});
test('USB errors still reach callback and rejected promise',async()=>{const failure=new Error('native error'),{usb}=usbFixture(failure);let callbackError;await assert.rejects(usb.find((err)=>{callbackError=err;}),e=>e===failure);assert.equal(callbackError,failure);});
test('USB target add and remove notifications are suppressed',()=>{const f=usbFixture();f.add(blade);f.remove(blade);assert.equal(f.emitted.length,0);});
test('USB peripheral add and remove notifications retained',()=>{const f=usbFixture();f.add(peripheral);f.remove(peripheral);assert.equal(f.emitted.length,15);assert(f.emitted.every(e=>e[1]===peripheral));});
test('HID enumeration filters target only',()=>{const f=hidFixture();const list=f.hid.devices();assert.equal(list.length,2);assert.equal(list[0],peripheral);});
test('cached target HID path rejected before native binding loads or opens',()=>{const f=hidFixture();assert.throws(()=>new f.hid.HID(blade.path),e=>e.code==='OPENBLADE_DEVICE_EXCLUDED');assert.equal(f.loads(),0);assert.equal(f.opens.length,0);});
test('target VID/PID constructor rejected before native open',()=>{const f=hidFixture();assert.throws(()=>new f.hid.HID(5426,736,'synthetic'),e=>e.code==='OPENBLADE_DEVICE_EXCLUDED');assert.equal(f.opens.length,0);});
test('peripheral path and other-vendor constructor retain native API',()=>{const f=hidFixture();const d=new f.hid.HID(peripheral.path);assert.equal(d.sendFeatureReport([1,2,3]),3);new f.hid.HID(1111,736);assert.equal(f.opens.length,2);assert.equal(f.opens[0][0],peripheral.path);});
test('patched ASAR references exact tested module bytes with valid hashes',()=>{const a=fs.readFileSync(path.join(root,'blocked.asar')),h=JSON.parse(a.subarray(16,16+a.readUInt32LE(12))),base=8+a.readUInt32LE(4);for(const n of ['openblade-device-exclusion.cjs','node_modules/rz-usb-detect/index.js','node_modules/node-rz-hid/nodehid.js']){let e=h;for(const p of n.split('/'))e=e.files[p];const b=a.subarray(base+Number(e.offset),base+Number(e.offset)+e.size);assert(b.equals(fs.readFileSync(path.join(root,'patched-blades',n))));assert.equal(crypto.createHash('sha256').update(b).digest('hex'),e.integrity.hash);}});

test('USB wrapper learns container before suppressing enumeration and hotplug',async()=>{
 const first={...blade,deviceContainerId:'D0000000-0000-0000-0000-000000000001'},second={...blade,deviceContainerId:'D0000000-0000-0000-0000-000000000002'};
 const f=usbFixture(null,[first]);assert.equal((await f.usb.find()).length,0);assert.equal(helper.observedBladeDevice(first),true);
 f.add(second);assert.equal(helper.observedBladeDevice(second),true);assert.equal(f.emitted.length,0);
 f.remove(second);assert.equal(helper.observedBladeDevice(second),true);assert.equal(f.emitted.length,0);
});
test('USB wrapper does not learn partial device results accompanying an error',async()=>{
 const d={...blade,deviceContainerId:'D0000000-0000-0000-0000-000000000003'},f=usbFixture(new Error('fixture'),[d]);
 await assert.rejects(f.usb.find());assert.equal(helper.observedBladeDevice(d),false);
});
