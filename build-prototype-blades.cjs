'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=__dirname,sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const meta=JSON.parse(fs.readFileSync(path.join(root,'source-metadata.json')));
const archive=fs.readFileSync(path.join(root,'original.asar'));
if(meta.version!=='4.0.821'||sha(archive)!=='d465c0f2a9aa031160d6bad01f0f8cb0fc9f623fa2db7da3a6d89cc92e4ca775'||sha(archive)!==meta.sourceAsarSha256)throw Error('Original hash changed');
const header=JSON.parse(archive.subarray(16,16+archive.readUInt32LE(12))),base=8+archive.readUInt32LE(4);
const files=[];function walk(t,p=''){for(const [n,e] of Object.entries(t.files||{})){const k=p?p+'/'+n:n;if(e.files)walk(e,k);else files.push({path:k,entry:e});}}walk(header);
function original(name){const {entry:e}=files.find(x=>x.path===name)||{};if(!e||e.unpacked||e.link)throw Error('Unsupported input '+name);return archive.subarray(base+Number(e.offset),base+Number(e.offset)+e.size).toString();}
function replaceOnce(s,a,b){if(s.split(a).length!==2)throw Error('Patch anchor mismatch: '+a);return s.replace(a,b);}
const helperName='openblade-device-exclusion.cjs';
let usb=original('node_modules/rz-usb-detect/index.js');
usb="var obExclusion = require('../../"+helperName+"');\n"+usb;
usb=replaceOnce(usb,'args = args.concat(function(err, devices) {','args = args.concat(function(err, devices) {\n                devices = obExclusion.visibleDevices(devices, !err);');
usb=replaceOnce(usb,'detection.registerAdded(function(device) {','detection.registerAdded(function(device) {\n        obExclusion.observeDevice(device); if (obExclusion.blockedDevice(device)) return;');
usb=replaceOnce(usb,'detection.registerRemoved(function(device) {','detection.registerRemoved(function(device) {\n        obExclusion.observeDevice(device); if (obExclusion.blockedDevice(device)) return;');
let hid=original('node_modules/node-rz-hid/nodehid.js');
hid="var obExclusion = require('../../"+helperName+"');\n"+hid;
hid=replaceOnce(hid,'function HID() {','function HID() {\n    obExclusion.rejectOpen(arguments);');
hid=replaceOnce(hid,'return binding.devices.apply(HID,arguments);','return obExclusion.visibleDevices(binding.devices.apply(HID,arguments));');
const changed=new Map([['node_modules/rz-usb-detect/index.js',Buffer.from(usb)],['node_modules/node-rz-hid/nodehid.js',Buffer.from(hid)],[helperName,fs.readFileSync(path.join(root,'device-exclusion-universal.cjs'))]]);

let main=original('electron/main.js');
main='const obNativeExclusion=require("../openblade-native-exclusion.cjs");\n'+main;
for(const [route,callee] of [['ffiPreload','Ve.callDLL'],['ffiPreloadAsync','Ve.callDLLAsync'],['ffiSubPreloadAsync','Ge.callDLLAsync']]) {
 const asyncText=route==='ffiPreload'?'':'async';
 const anchor='n.handle("'+route+'",'+asyncText+'(e,o,n)=>'+callee+'(e,o,n))';
 const replacement='n.handle("'+route+'",'+asyncText+'(e,o,n)=>(obNativeExclusion.assertAllowed("'+route+'",e,n),'+callee+'(e,o,n)))';
 main=replaceOnce(main,anchor,replacement);
}
main=replaceOnce(main,'n.handle("mappingEngineAction",async(e,o)=>Ke.callDLL(e,o))','n.handle("mappingEngineAction",async(e,o)=>(obNativeExclusion.assertAllowed("mappingEngineAction",e,o),Ke.callDLL(e,o)))');
for(const route of ['simpleServiceAction','lightingDriver']) main=replaceOnce(main,'n.handle("'+route+'",async(e,o)=>{','n.handle("'+route+'",async(e,o)=>{obNativeExclusion.assertAllowed("'+route+'",e,o);');
// Guard the synchronous system-native dispatch, retaining non-native UI actions.
main=replaceOnce(main,'return no.callDLL(n,i);','return obNativeExclusion.assertAllowed("electronAction",n,i),no.callDLL(n,i);');
// Service helper routes bypass the synchronous system-utility dispatch above.
for(const [action,callee] of [['GetServiceStatus','To'],['StartService','Mo'],['StopService','Po']]) {
 main=replaceOnce(main,'case"'+action+'":return '+callee+'(Xe,i);','case"'+action+'":return obNativeExclusion.assertAllowed("electronAction",n,i),'+callee+'(Xe,i);');
}
let mapping=original('electron/modules/mapping_engine/win/index.js');
mapping='const obDeviceExclusion=require("../../../../openblade-device-exclusion.cjs");\n'+mapping;
mapping=replaceOnce(mapping,'if(a){o?.ffiMappingEngine?.eventEmitter.emit','if(a&&!obDeviceExclusion.blockedDevice(a)){o?.ffiMappingEngine?.eventEmitter.emit');
changed.set('electron/main.js',Buffer.from(main));
changed.set('electron/modules/mapping_engine/win/index.js',Buffer.from(mapping));
changed.set('openblade-native-exclusion.cjs',fs.readFileSync(path.join(root,'native-exclusion-universal.cjs')));

changed.set('blade-device-registry.json',fs.readFileSync(path.join(root,'blade-device-registry.json')));
const payload=[archive.subarray(base)];let offset=payload[0].length;
const changes=[];
for(const [name,data] of changed){if(name.endsWith('.json'))JSON.parse(data.toString());else new vm.Script(data.toString(),{filename:name});const parts=name.split('/');let parent=header;for(const p of parts.slice(0,-1)){parent.files[p]??={files:{}};parent=parent.files[p];}const old=parent.files[parts.at(-1)];const blockSize=old?.integrity?.blockSize||4194304;const blocks=[];for(let i=0;i<data.length;i+=blockSize)blocks.push(sha(data.subarray(i,i+blockSize)));parent.files[parts.at(-1)]={...(old||{}),size:data.length,offset:String(offset),integrity:{algorithm:'SHA256',hash:sha(data),blockSize,blocks}};payload.push(data);offset+=data.length;const dest=path.join(root,'patched-blades',name);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,data);changes.push({path:name,beforeSha256:old?sha(Buffer.from(original(name))):null,afterSha256:sha(data)});}
const json=Buffer.from(JSON.stringify(header)),aligned=Math.ceil(json.length/4)*4,prefix=Buffer.alloc(16+aligned);prefix.writeUInt32LE(4,0);prefix.writeUInt32LE(8+aligned,4);prefix.writeUInt32LE(4+aligned,8);prefix.writeUInt32LE(json.length,12);json.copy(prefix,16);
const result=Buffer.concat([prefix,...payload]);fs.writeFileSync(path.join(root,'patched-blades.offline-only.asar'),result);
const newBase=8+result.readUInt32LE(4),newHeader=JSON.parse(result.subarray(16,16+result.readUInt32LE(12)));let verified=0;
for(const {path:name,entry:e} of files){if(e.unpacked||e.link||changed.has(name))continue;let n=newHeader;for(const p of name.split('/'))n=n.files[p];const a=archive.subarray(base+Number(e.offset),base+Number(e.offset)+e.size),b=result.subarray(newBase+Number(n.offset),newBase+Number(n.offset)+n.size);if(!a.equals(b))throw Error('Untouched file changed: '+name);verified++;}
const report={sourceVersion:meta.version,originalAsarSha256:sha(archive),patchedAsarSha256:sha(result),untouchedPackedFilesVerified:verified,changes,installedFilesModified:false,appLaunched:false};fs.writeFileSync(path.join(root,'patch-manifest-blades.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
