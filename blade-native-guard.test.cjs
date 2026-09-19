'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=require('./test-root.cjs'),policy=require(require('./test-root.cjs')+'/patched-blades/openblade-native-exclusion.cjs');
const main=fs.readFileSync(path.join(root,'patched-blades/electron/main.js'),'utf8');
const event=id=>({sender:{getURL:()=>`https://apps.razer.com/products/${id}/mw/`}});
const bladeFile='C:/Users/TestUser/AppData/Local/Razer/RazerAppEngine/User Data/Apps/Common/bladeCommon/blade2Native_v1.0.46.0.dll';
function registration(route){const start=main.search(new RegExp('[A-Za-z_$][\\w$]*\\.handle\\("'+route+'",'));assert(start>=0);let depth=0,quote=null,escape=false;for(let i=start;i<main.length;i++){const c=main[i];if(quote){if(escape){escape=false;continue;}if(c==='\\'){escape=true;continue;}if(c===quote)quote=null;continue;}if(c==='"'||c==="'"||c==='`'){quote=c;continue;}if(c==='(')depth++;if(c===')'&&--depth===0)return main.slice(start,i+1);}throw Error('Missing registration end');}
function handler(route){let fn,calls=0;const forward=()=>{calls++;return {result:true};},code=registration(route),ipc=/^([$\w]+)\.handle/.exec(code)[1],context={[ipc]:{handle:(r,f)=>{assert.equal(r,route);fn=f;}},obNativeExclusion:policy};for(const match of code.matchAll(/([$\w]+)\.(callDLLAsync|callDLL|registerMainDLL)\(/g)){context[match[1]]??={};context[match[1]][match[2]]=match[2]==='registerMainDLL'?()=>{}:forward;}vm.runInNewContext(code,context,{timeout:1000});return{fn,calls:()=>calls};}

for(const route of ['ffiPreload','ffiPreloadAsync','ffiSubPreloadAsync','mappingEngineAction','simpleServiceAction','lightingDriver']){
 test(route+': actual patched handler rejects Blade sender before forwarding',async()=>{const h=handler(route);await assert.rejects(async()=>route.startsWith('ffi')?h.fn(event(736),'channel',{action:'synthetic'}):h.fn(event(736),{action:'synthetic'}),e=>e.code==='OPENBLADE_NATIVE_DEVICE_EXCLUDED');assert.equal(h.calls(),0);});
 test(route+': actual patched handler preserves peripheral sender',async()=>{const h=handler(route);const r=await(route.startsWith('ffi')?h.fn(event(153),'channel',{action:'synthetic'}):h.fn(event(153),{action:'synthetic'}));assert.equal(r.result,true);assert.equal(h.calls(),1);});
}
test('known Blade library path blocked even from shared background sender',async()=>{const h=handler('ffiPreload');await assert.rejects(async()=>h.fn(event('background'),'channel',{action:'ConfigureFFI',payload:{dllPath:bladeFile}}),e=>e.code==='OPENBLADE_NATIVE_DEVICE_EXCLUDED');assert.equal(h.calls(),0);});
test('known Blade helper executable launch blocked',()=>{assert.throws(()=>policy.assertAllowed('simpleServiceAction',event('background'),{action:'simpleLaunchUserAppProcess',payload:{filePath:bladeFile.replace('blade2Native_v1.0.46.0.dll','Blade2NativeApp_v1.0.1.0.exe')}}),e=>e.code==='OPENBLADE_NATIVE_DEVICE_EXCLUDED');});
test('explicit target mapping registration blocked without Blade sender',()=>{assert.throws(()=>policy.assertAllowed('mappingEngineAction',event('background'),{payload:{usbDevice:{vendorId:5426,productId:736}}}),e=>e.code==='OPENBLADE_NATIVE_DEVICE_EXCLUDED');});
test('shared system library from shared sender remains available, an explicit coverage limit',()=>{assert.doesNotThrow(()=>policy.assertAllowed('ffiPreload',event('background'),{action:'ConfigureFFI',payload:{dllPath:'C:/Apps/Common/RzDLLService/RzSystemCommon_v1.0.29.0.dll'}}));});
test('near-match product URL is not treated as Blade',()=>{assert.equal(policy.bladeSender(event(7360)),false);});
test('native mapping device-event callback filters target while retaining peripheral',()=>{const code=fs.readFileSync(path.join(root,'patched-blades/electron/modules/mapping_engine/win/index.js'),'utf8');const begin=code.indexOf('createCbDeviceEvent=()=>{'),end=code.indexOf(';registerDeviceEvent=',begin);assert(begin>=0&&end>begin);const emitted=[],sent=[];const context={obDeviceExclusion:require(require('./test-root.cjs')+'/patched-blades/openblade-device-exclusion.cjs'),console:{log(){}},e:{Callback:(...args)=>args.at(-1)},t:false,o:{ffiMappingEngine:{eventEmitter:{emit:(...args)=>emitted.push(args)},deviceEventList:['fixture']}},i:{getAllWebContents:()=>[{getURL:()=> 'fixture',isDestroyed:()=>false,isCrashed:()=>false,send:(...args)=>sent.push(args)}]},g:()=>false};vm.createContext(context);const klass=vm.runInContext('(class {'+code.slice(begin,end)+'})',context,{timeout:1000});const instance=new klass();instance.createCbDeviceEvent();instance.cbDeviceEvent(JSON.stringify({vendorId:5426,productId:736,containerId:'fixture'}),5,'{}',0);assert.equal(emitted.length,0);assert.equal(sent.length,0);instance.cbDeviceEvent(JSON.stringify({vendorId:5426,productId:153,containerId:'fixture'}),5,'{}',0);assert.equal(emitted.length,1);assert.equal(sent.length,1);});

for(const route of ['ffiPreload','ffiPreloadAsync','ffiSubPreloadAsync','mappingEngineAction','simpleServiceAction','lightingDriver']){
 test(route+': Blade child frame in shared window rejected before native forwarding',async()=>{
  const h=handler(route),e={sender:{getURL:()=> 'https://apps.razer.com/synapse/background-manager/'},senderFrame:{url:'https://apps.razer.com/products/736/mw/'}};
  await assert.rejects(async()=>route.startsWith('ffi')?h.fn(e,'channel',{action:'synthetic'}):h.fn(e,{action:'synthetic'}),error=>error.code==='OPENBLADE_NATIVE_DEVICE_EXCLUDED');
  assert.equal(h.calls(),0);
 });
}
test('peripheral child frame in shared window retains native access',async()=>{
 const h=handler('ffiPreload'),e={sender:{getURL:()=> 'https://apps.razer.com/synapse/background-manager/'},senderFrame:{url:'https://apps.razer.com/products/3907/mw/'}};
 assert.equal((await h.fn(e,'channel',{action:'synthetic'})).result,true);assert.equal(h.calls(),1);
});
test('disposed child frame does not suppress known Blade window identity',()=>{
 const e=event(736);Object.defineProperty(e,'senderFrame',{get(){throw Error('disposed');}});
 assert.equal(policy.bladeSender(e),true);
});
test('disposed window does not suppress known Blade child frame identity',()=>{
 const e={sender:{getURL(){throw Error('disposed');}},senderFrame:{url:'https://apps.razer.com/synapse/products/736/mw/'}};
 assert.equal(policy.bladeSender(e),true);
});
test('lookalike frame origin remains outside exact Razer product classification',()=>{
 const e={sender:{getURL:()=> 'https://apps.razer.com/synapse/background-manager/'},senderFrame:{url:'https://apps.razer.com.example.invalid/products/736/mw/'}};
 assert.equal(policy.bladeSender(e),false);
});

for(const route of ['ffiPreload','ffiPreloadAsync','ffiSubPreloadAsync'])for(const action of ['SetAPIToCallWhenExitDevice','SetAPIToCallWhenShutdown','SetAPIToCallWhenSuspend']) {
 test(route+': '+action+' rejects observed Blade container from shared sender',async()=>{
  const devices=require(require('./test-root.cjs')+'/patched-blades/openblade-device-exclusion.cjs');
  const guid='10000000-0000-0000-0000-000000000736';
  devices.visibleDevices([{vendorId:5426,productId:736,deviceContainerId:guid}]);
  const h=handler(route),shared=event('background');
  await assert.rejects(async()=>h.fn(shared,'fixture',{action,payload:{productId:736,deviceContainerId:guid,actionArgs:[['DeviceInit']]}}),e=>e.code==='OPENBLADE_NATIVE_DEVICE_EXCLUDED');
  assert.equal(h.calls(),0);
 });
}
test('peripheral lifecycle registration and Blade callback removal remain available',async()=>{
 const h=handler('ffiPreload'),guid='10000000-0000-0000-0000-000000000736';
 await h.fn(event('background'),'fixture',{action:'SetAPIToCallWhenSuspend',payload:{vendorId:5426,productId:153,deviceContainerId:guid}});
 await h.fn(event('background'),'fixture',{action:'RemoveAPIToCallWhenSuspend',payload:{productId:736,deviceContainerId:guid}});
 assert.equal(h.calls(),2);
});

test('observed cooling-pad shutdown registration remains available on real IoT channel',async()=>{
 const h=handler('ffiPreload'),devices=require(require('./test-root.cjs')+'/patched-blades/openblade-device-exclusion.cjs');
 const guid='E0000000-0000-0000-0000-000000003907';
 devices.visibleDevices([{vendorId:5426,productId:3907,deviceContainerId:guid}]);
 const result=await h.fn(event(3907),'IoTSDKNative_Action',{action:'SetAPIToCallWhenShutdown',payload:{productId:3907,deviceContainerId:guid,actionArgs:[['IOT_RunCmdFw25','fixture-host','SetDeviceMode','fixture-bytes',0,false]]}});
 assert.equal(result.result,true);assert.equal(h.calls(),1);
});
test('shared background SDK exit cleanup remains available',async()=>{
 const h=handler('ffiPreload');const result=await h.fn(event('background'),'fixture',{action:'ConfigureFFI_APIToCallWhenExit',payload:{actionArgs:'uninitSDK'}});
 assert.equal(result.result,true);assert.equal(h.calls(),1);
});

test('placeholder container cannot attribute a product-only shared callback to Blade',async()=>{
 const devices=require(require('./test-root.cjs')+'/patched-blades/openblade-device-exclusion.cjs');
 const deviceContainerId='{00000000-0000-0000-FFFF-FFFFFFFFFFFF}';
 devices.visibleDevices([{vendorId:5426,productId:736,deviceContainerId}]);
 const h=handler('ffiPreload');
 await h.fn(event('background'),'fixture',{action:'SetAPIToCallWhenShutdown',payload:{productId:736,deviceContainerId,actionArgs:[['DeviceInit']]}});
 assert.equal(h.calls(),1);
});
test('explicit Blade vendor identity still blocks callback with placeholder container',async()=>{
 const h=handler('ffiPreload');
 await assert.rejects(async()=>h.fn(event('background'),'fixture',{action:'SetAPIToCallWhenShutdown',payload:{vendorId:5426,productId:736,deviceContainerId:'{00000000-0000-0000-FFFF-FFFFFFFFFFFF}',actionArgs:[['DeviceInit']]}}),e=>e.code==='OPENBLADE_NATIVE_DEVICE_EXCLUDED');
 assert.equal(h.calls(),0);
});
