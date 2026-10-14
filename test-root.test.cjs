'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process'),{prepare}=require('./build-prototype-blades.cjs');

function asar(entries){const h={files:{}},data=[];let offset=0;for(const [name,source] of Object.entries(entries)){const bytes=Buffer.from(source),parts=name.split('/');let parent=h;for(const p of parts.slice(0,-1))parent=parent.files[p]??={files:{}};parent.files[parts.at(-1)]={size:bytes.length,offset:String(offset)};data.push(bytes);offset+=bytes.length;}const json=Buffer.from(JSON.stringify(h)),aligned=Math.ceil(json.length/4)*4,p=Buffer.alloc(16+aligned);p.writeUInt32LE(4,0);p.writeUInt32LE(8+aligned,4);p.writeUInt32LE(4+aligned,8);p.writeUInt32LE(json.length,12);json.copy(p,16);return Buffer.concat([p,...data]);}
function fixture(){return {
 'node_modules/rz-usb-detect/index.js':'args = args.concat(function(err, devices) {}); detection.registerAdded(function(device) {}); detection.registerRemoved(function(device) {});',
 'node_modules/node-rz-hid/nodehid.js':'function HID() {} function enumerate(){return binding.devices.apply(HID,arguments);}',
 'electron/main.js':'ipc.handle("ffiPreload",(event,a,b)=>nativeAlias.callDLL(event,a,b));ipc.handle("ffiPreloadAsync",async(event,a,b)=>nativeAlias.callDLLAsync(event,a,b));ipc.handle("ffiSubPreloadAsync",async(event,a,b)=>otherAlias.callDLLAsync(event,a,b));ipc.handle("mappingEngineAction",async(event,a)=>mappingAlias.callDLL(event,a));ipc.handle("simpleServiceAction",async(event,a)=>{});ipc.handle("lightingDriver",async(event,a)=>{});ipc.handle("electronAction",async(event,request)=>{switch(request.action){case"GetServiceStatus":return statusAlias(service,request);case"StartService":return startAlias(service,request);case"StopService":return stopAlias(service,request);}return systemAlias.callDLL(event,request);});',
 'electron/modules/mapping_engine/win/index.js':'if(device){engine?.ffiMappingEngine?.eventEmitter.emit("device",device);}'
};}
function runTestRoot(preparation){const env={...process.env};if(preparation===undefined)delete env.BLOCKER_PREPARATION_DIRECTORY;else env.BLOCKER_PREPARATION_DIRECTORY=preparation;return spawnSync(process.execPath,['-e','process.stdout.write(require(process.argv[1]))',path.join(__dirname,'test-root.cjs')],{env,encoding:'utf8'});}

test('local module tests require an explicit preparation directory',()=>{const result=runTestRoot();assert.notEqual(result.status,0);assert.match(result.stderr,/Set BLOCKER_PREPARATION_DIRECTORY/);});

test('local module tests accept only the explicitly selected current preparation',t=>{
 const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'blocker-test-root-'));t.after(()=>fs.rmSync(scratch,{recursive:true,force:true}));
 const source=path.join(scratch,'original.asar'),executable=path.join(scratch,'RazerAppEngine.exe'),preparation=path.join(scratch,'prepared');
 fs.writeFileSync(source,asar(fixture()));fs.writeFileSync(executable,'inert executable');prepare(source,executable,preparation);
 const valid=runTestRoot(preparation);assert.equal(valid.status,0,valid.stderr);assert.equal(valid.stdout,path.resolve(preparation));
 const fixtureModule=path.join(preparation,'patched-blades','openblade-device-exclusion.cjs');fs.appendFileSync(fixtureModule,' ');
 const altered=runTestRoot(preparation);assert.notEqual(altered.status,0);assert.match(altered.stderr,/stale or failed integrity verification/);
});
