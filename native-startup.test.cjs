'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
test('patched mapping engine still initializes native code before renderer/device identity',async()=>{
 const module={exports:{}},calls=[];
 const allowed={
  'ffi-napi-rz':{CanUseAnneCallback:()=>false,Callback:(...args)=>args.at(-1)},
  crypto:require('node:crypto'),events:require('node:events'),
  electron:{webContents:{getAllWebContents:()=>[]}},
  '../../../lib/globalNodeVar':{globalNodeVar:{events:{on(){}}}},
  '../../../lib/common':{},
  'async-mutex':{Mutex:class {}},
  '../../../errorMsgConst':{},
  '../../../mainSubFunction':{},
  '../../sentry/index':{},
  '../../../lib/filterDriverInstallTracker':{},
  '../../../../openblade-device-exclusion.cjs':require('./patched-blades/openblade-device-exclusion.cjs')
 };
 const context={module,console:{log(){},warn(){}},process:{platform:'win32'},require(name){if(!Object.hasOwn(allowed,name))throw Error('Forbidden real dependency: '+name);return allowed[name];}};
 vm.runInNewContext(fs.readFileSync(__dirname+'/patched-blades/electron/modules/mapping_engine/win/index.js','utf8'),context,{timeout:1000});
 const engine=new module.exports.FFIMappingEngine();
 engine.loadLatestDLL=async(file)=>{calls.push({type:'load',file});engine.libFFI={mappingEngineInitialize(callback){calls.push({type:'native-initialize'});callback();}};return true;};
 await engine.initDll('C:/offline-fixture/mapping_engine.dll');
 assert.equal(engine.isInit,true);assert.deepEqual(calls.map(x=>x.type),['load','native-initialize']);
});
