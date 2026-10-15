'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process'),{transform,prepare}=require('./build-prototype-blades.cjs'),{sourceFiles,sourceIdentity,verifyPreparation}=require('./preparation-identity.cjs');
function asar(entries){const h={files:{}},data=[];let offset=0;for(const [name,source] of Object.entries(entries)){const bytes=Buffer.from(source),parts=name.split('/');let parent=h;for(const p of parts.slice(0,-1))parent=parent.files[p]??={files:{}};parent.files[parts.at(-1)]={size:bytes.length,offset:String(offset)};data.push(bytes);offset+=bytes.length;}const json=Buffer.from(JSON.stringify(h)),aligned=Math.ceil(json.length/4)*4,p=Buffer.alloc(16+aligned);p.writeUInt32LE(4,0);p.writeUInt32LE(8+aligned,4);p.writeUInt32LE(4+aligned,8);p.writeUInt32LE(json.length,12);json.copy(p,16);return Buffer.concat([p,...data]);}
function fixture(){return {
 'package.json':'{"version":"99.100.12345"}',
 'untouched.txt':'a different future build',
 'node_modules/rz-usb-detect/index.js':'args = args.concat(function(err, devices) {}); detection.registerAdded(function(device) {}); detection.registerRemoved(function(device) {});',
 'node_modules/node-rz-hid/nodehid.js':'function HID() {} function enumerate(){return binding.devices.apply(HID,arguments);}',
 'electron/main.js':'ipc.handle("ffiPreload",(event,a,b)=>nativeAlias.callDLL(event,a,b));ipc.handle("ffiPreloadAsync",async(event,a,b)=>nativeAlias.callDLLAsync(event,a,b));ipc.handle("ffiSubPreloadAsync",async(event,a,b)=>otherAlias.callDLLAsync(event,a,b));ipc.handle("mappingEngineAction",async(event,a)=>mappingAlias.callDLL(event,a));ipc.handle("simpleServiceAction",async(event,a)=>{});ipc.handle("lightingDriver",async(event,a)=>{});ipc.handle("electronAction",async(event,request)=>{switch(request.action){case"GetServiceStatus":return statusAlias(service,request);case"StartService":return startAlias(service,request);case"StopService":return stopAlias(service,request);}return systemAlias.callDLL(event,request);});',
 'electron/modules/mapping_engine/win/index.js':'if(device){engine?.ffiMappingEngine?.eventEmitter.emit("device",device);}'
};}
test('future version and renamed native/service aliases transform without hash allowlist',()=>{const result=transform(asar(fixture()));assert.equal(result.report.changes.length,7);assert.equal(result.report.untouchedPackedFilesVerified,2);assert.match(result.changed.get('electron/main.js').toString(),/assertAllowed\("electronAction",event,request\),startAlias/);assert.equal(result.report.bladeProductIds.length,40);});
test('each missing mandatory native route stops the entire transformation',()=>{for(const route of ['ffiPreload','ffiPreloadAsync','ffiSubPreloadAsync','mappingEngineAction','simpleServiceAction','lightingDriver','electronAction','GetServiceStatus','StartService','StopService']){const f=fixture();f['electron/main.js']=f['electron/main.js'].replace('"'+route+'"','"changedRoute"');assert.throws(()=>transform(asar(f)),/missing or ambiguous/);}});
test('duplicate anchor and already-patched source are refused',()=>{const f=fixture();f['electron/main.js']+=f['electron/main.js'];assert.throws(()=>transform(asar(f)),/missing or ambiguous/);assert.throws(()=>transform(transform(asar(fixture())).result),/Already patched/);});
test('missing wrapper, changed mapping and malformed archive fail closed',()=>{const f=fixture();delete f['node_modules/node-rz-hid/nodehid.js'];assert.throws(()=>transform(asar(f)),/Unsupported input/);const m=fixture();m['electron/modules/mapping_engine/win/index.js']='otherLayout();';assert.throws(()=>transform(asar(m)),/missing or ambiguous/);assert.throws(()=>transform(Buffer.from('bad')),/Invalid ASAR/);});
test('preparation records actual new executable and source hashes without replacing prior output',t=>{const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'blocker-build-'));t.after(()=>fs.rmSync(scratch,{recursive:true,force:true}));const source=path.join(scratch,'original.asar'),exe=path.join(scratch,'RazerAppEngine.exe'),out=path.join(scratch,'one');fs.writeFileSync(source,asar(fixture()));fs.writeFileSync(exe,'future executable fixture');const m=prepare(source,exe,out);assert.match(m.executableSha256,/^[a-f0-9]{64}$/);assert.equal(m.patchSourceSha256,sourceIdentity());assert(fs.readFileSync(source).equals(fs.readFileSync(path.join(out,'original.asar'))));assert.throws(()=>prepare(source,exe,out),/already exists/);fs.writeFileSync(exe,'another future executable');const second=prepare(source,exe,path.join(scratch,'two'));assert.notEqual(second.executableSha256,m.executableSha256);const broken=fixture();broken['electron/main.js']='changed layout';fs.writeFileSync(source,asar(broken));assert.throws(()=>prepare(source,exe,path.join(scratch,'invalid')),/missing or ambiguous/);assert(!fs.existsSync(path.join(scratch,'invalid')));assert(fs.existsSync(path.join(out,'original.asar')));});

test('patch source identity is deterministic and covers every transformation source',t=>{
 const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'blocker-source-identity-'));t.after(()=>fs.rmSync(scratch,{recursive:true,force:true}));
 for(const [index,name] of sourceFiles.entries())fs.writeFileSync(path.join(scratch,name),'source '+index);
 const expected=sourceIdentity(scratch);assert.match(expected,/^[a-f0-9]{64}$/);assert.equal(sourceIdentity(scratch),expected);
 for(const name of sourceFiles){const file=path.join(scratch,name),before=fs.readFileSync(file);fs.appendFileSync(file,'x');assert.notEqual(sourceIdentity(scratch),expected,name);fs.writeFileSync(file,before);}
});

function makePreparation(t){const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'blocker-verify-'));t.after(()=>fs.rmSync(scratch,{recursive:true,force:true}));const source=path.join(scratch,'original.asar'),exe=path.join(scratch,'RazerAppEngine.exe'),output=path.join(scratch,'prepared');fs.writeFileSync(source,asar(fixture()));fs.writeFileSync(exe,'inert executable');prepare(source,exe,output);return output;}
function readManifest(output){return JSON.parse(fs.readFileSync(path.join(output,'preparation.json'),'utf8'));}
function writeManifest(output,manifest){fs.writeFileSync(path.join(output,'preparation.json'),JSON.stringify(manifest,null,2));}
test('semantic preparation verification accepts deterministic current output and CLI reports booleans',t=>{
 const output=makePreparation(t);assert.equal(verifyPreparation(output),true);
 const identity=spawnSync(process.execPath,[path.join(__dirname,'preparation-identity.cjs'),'--source-identity'],{encoding:'utf8'});assert.equal(identity.status,0);assert.equal(identity.stdout.trim(),sourceIdentity());
 const verified=spawnSync(process.execPath,[path.join(__dirname,'preparation-identity.cjs'),'--verify-preparation',output],{encoding:'utf8'});assert.equal(verified.status,0);assert.equal(verified.stdout.trim(),'true');
});
test('semantic preparation verification rejects stale and legacy source identity',t=>{
 const output=makePreparation(t),manifest=readManifest(output);manifest.patchSourceSha256='0'.repeat(64);writeManifest(output,manifest);assert.equal(verifyPreparation(output),false);
 delete manifest.patchSourceSha256;writeManifest(output,manifest);assert.equal(verifyPreparation(output),false);
 const rejected=spawnSync(process.execPath,[path.join(__dirname,'preparation-identity.cjs'),'--verify-preparation',output],{encoding:'utf8'});assert.equal(rejected.status,0);assert.equal(rejected.stdout.trim(),'false');
});
test('semantic preparation verification rejects planted archive and altered fixture module',t=>{
 const output=makePreparation(t),blockedPath=path.join(output,'blocked.asar'),originalBlocked=fs.readFileSync(blockedPath),manifest=readManifest(output);
 fs.appendFileSync(blockedPath,'planted');manifest.patchedAsarSha256=crypto.createHash('sha256').update(fs.readFileSync(blockedPath)).digest('hex');writeManifest(output,manifest);assert.equal(verifyPreparation(output),false);
 fs.writeFileSync(blockedPath,originalBlocked);manifest.patchedAsarSha256=crypto.createHash('sha256').update(originalBlocked).digest('hex');writeManifest(output,manifest);assert.equal(verifyPreparation(output),true);
 fs.appendFileSync(path.join(output,'patched-blades','openblade-native-exclusion.cjs'),' ');assert.equal(verifyPreparation(output),false);
});

test('failed structural preparation produces a sanitized issue report and no patch output',t=>{const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'blocker-incompatible-'));t.after(()=>fs.rmSync(scratch,{recursive:true,force:true}));const source=path.join(scratch,'private-serial-source.asar'),exe=path.join(scratch,'RazerAppEngine.exe'),output=path.join(scratch,'output'),f=fixture();f['electron/main.js']=f['electron/main.js'].replace('"ffiPreload"','"changedRoute"');fs.writeFileSync(source,asar(f));fs.writeFileSync(exe,'inert executable');const before=fs.readFileSync(source);let failure;try{prepare(source,exe,output);}catch(error){failure=error;}assert(failure);const old=console.error;console.error=()=>{};let text;try{text=require('./failure-report.cjs').report({stage:'Build',error:failure,archive:source,executable:exe},path.join(scratch,'diagnostics'));}finally{console.error=old;}assert.match(text,/Anchor: ffiPreload/);assert.match(text,/Anchor matches: 0/);assert(!text.includes(scratch));assert(!text.includes('private-serial'));assert(!fs.existsSync(output));assert(fs.readFileSync(source).equals(before));assert.equal(fs.readdirSync(path.join(scratch,'diagnostics')).length,1);});

test('generated archive and patch record include all five experimental OpenBlade identities', () => {
 const built=transform(asar(fixture()));
 const header=JSON.parse(built.result.subarray(16,16+built.result.readUInt32LE(12)));
 const base=8+built.result.readUInt32LE(4);
 function packed(name){let entry=header;for(const part of name.split('/'))entry=entry.files[part];return built.result.subarray(base+Number(entry.offset),base+Number(entry.offset)+entry.size);}
 const registry=JSON.parse(packed('blade-device-registry.json'));
 const module={exports:{}};
 require('node:vm').runInNewContext(packed('openblade-device-exclusion.cjs').toString(),{module,require:name=>{assert.equal(name,'./blade-device-registry.json');return registry;}});
 const policy=module.exports;
 for(const productId of [0x029f,0x029d,0x02c5,0x0255,0x02a0]){
  assert(built.report.bladeProductIds.includes(productId));
  assert(registry.devices.some(d=>d.vendorId===0x1532&&d.productId===productId));
  assert.equal(policy.blockedDevice({vendorId:0x1532,productId}),true);
  assert.equal(policy.blockedDevice({vendorId:0x1234,productId}),false);
 }
 assert.equal(policy.blockedDevice({vendorId:0x1532,productId:0x00d1}),false);
});
