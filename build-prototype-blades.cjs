'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm');
const root=__dirname,sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function transform(archive) {
 if(archive.length<16||archive.readUInt32LE(0)!==4||16+archive.readUInt32LE(12)>archive.length)throw Error('Invalid ASAR header');
 const header=JSON.parse(archive.subarray(16,16+archive.readUInt32LE(12))),base=8+archive.readUInt32LE(4);
 const files=[];function walk(t,p=''){for(const [n,e] of Object.entries(t.files||{})){const k=p?p+'/'+n:n;if(e.files)walk(e,k);else files.push({path:k,entry:e});}}walk(header);
 function original(name){const {entry:e}=files.find(x=>x.path===name)||{};if(!e||e.unpacked||e.link||!Number.isSafeInteger(Number(e.offset))||Number(e.offset)<0||!Number.isSafeInteger(e.size)||e.size<0||base+Number(e.offset)+e.size>archive.length)throw Error('Unsupported input '+name);return archive.subarray(base+Number(e.offset),base+Number(e.offset)+e.size).toString();}
 function once(s,a,b){const matches=typeof a==='string'?s.split(a).length-1:[...s.matchAll(new RegExp(a.source,a.flags.includes('g')?a.flags:a.flags+'g'))].length;if(matches!==1){const label=String(a).match(/ffiSubPreloadAsync|ffiPreloadAsync|ffiPreload|mappingEngineAction|simpleServiceAction|lightingDriver|GetServiceStatus|StartService|StopService|registerAdded|registerRemoved|callDLL|ffiMappingEngine|binding.devices|function HID|args = args.concat/)?.[0]?.replace(/[^a-zA-Z0-9_-]/g,'_')||'required-edit';throw Error('Mandatory patch anchor missing or ambiguous ('+label+'; matches='+matches+')');}return s.replace(a,b);}
 if(files.some(x=>x.path==='openblade-device-exclusion.cjs'))throw Error('Already patched input; use its preserved original');
 const helperName='openblade-device-exclusion.cjs';
 let usb="var obExclusion = require('../../"+helperName+"');\n"+original('node_modules/rz-usb-detect/index.js');
 usb=once(usb,'args = args.concat(function(err, devices) {','args = args.concat(function(err, devices) {\n                devices = obExclusion.visibleDevices(devices, !err);');
 for(const kind of ['Added','Removed'])usb=once(usb,'detection.register'+kind+'(function(device) {','detection.register'+kind+'(function(device) {\n        obExclusion.observeDevice(device); if (obExclusion.blockedDevice(device)) return;');
 let hid="var obExclusion = require('../../"+helperName+"');\n"+original('node_modules/node-rz-hid/nodehid.js');
 hid=once(hid,'function HID() {','function HID() {\n    obExclusion.rejectOpen(arguments);');
 hid=once(hid,'return binding.devices.apply(HID,arguments);','return obExclusion.visibleDevices(binding.devices.apply(HID,arguments));');
 const changed=new Map([['node_modules/rz-usb-detect/index.js',Buffer.from(usb)],['node_modules/node-rz-hid/nodehid.js',Buffer.from(hid)],[helperName,fs.readFileSync(path.join(root,'device-exclusion-universal.cjs'))]]);
 let main='const obNativeExclusion=require("../openblade-native-exclusion.cjs");\n'+original('electron/main.js');
 const id='[A-Za-z_$][\\w$]*';
 // Route names and argument relationships are structural anchors; aliases may change.
 for(const route of ['ffiPreload','ffiPreloadAsync','ffiSubPreloadAsync','mappingEngineAction']) {
  const count=route==='mappingEngineAction'?2:3,method=route==='ffiPreload'||count===2?'callDLL':'callDLLAsync';
  const parameters=count===2?'('+id+'),('+id+')':'('+id+'),('+id+'),('+id+')';
  const args=count===2?'\\2,\\3':'\\2,\\3,\\4';
  const re=new RegExp('('+id+'\\.handle\\("'+route+'",(?:async)?\\('+parameters+'\\)=>)('+id+'\\.'+method+'\\('+args+'\\))\\)');
  main=once(main,re,(whole,prefix,event,arg2,arg3,call)=>{if(count===2){call=arg3;arg3=arg2;}return prefix+'(obNativeExclusion.assertAllowed("'+route+'",'+event+','+arg3+'),'+call+'))';});
 }
 for(const route of ['simpleServiceAction','lightingDriver'])main=once(main,new RegExp('('+id+'\\.handle\\("'+route+'",async\\(('+id+'),('+id+')\\)=>\\{)'),(_,prefix,event,arg)=>prefix+'obNativeExclusion.assertAllowed("'+route+'",'+event+','+arg+');');
 main=once(main,new RegExp('return ('+id+'\\.callDLL\\(('+id+'),('+id+')\\));'),(_,call,event,arg)=>'return obNativeExclusion.assertAllowed("electronAction",'+event+','+arg+'),'+call+';');
 const actionHandlers=[...main.matchAll(new RegExp(id+'\\.handle\\("electronAction",async\\(('+id+'),('+id+')\\)=>\\{','g'))];
 if(actionHandlers.length!==1)throw Error('electronAction handler missing or ambiguous');
 for(const action of ['GetServiceStatus','StartService','StopService'])main=once(main,new RegExp('(case"'+action+'":return )('+id+'\\('+id+','+actionHandlers[0][2]+'\\));'),(_,prefix,call)=>prefix+'obNativeExclusion.assertAllowed("electronAction",'+actionHandlers[0][1]+','+actionHandlers[0][2]+'),'+call+';');
 let mapping='const obDeviceExclusion=require("../../../../openblade-device-exclusion.cjs");\n'+original('electron/modules/mapping_engine/win/index.js');
 mapping=once(mapping,/if\(([$\w]+)\)\{([$\w]+)\?\.ffiMappingEngine\?\.eventEmitter\.emit/,(_,device,owner)=>'if('+device+'&&!obDeviceExclusion.blockedDevice('+device+')){'+owner+'?.ffiMappingEngine?.eventEmitter.emit');
 changed.set('electron/main.js',Buffer.from(main));changed.set('electron/modules/mapping_engine/win/index.js',Buffer.from(mapping));
 changed.set('openblade-native-exclusion.cjs',fs.readFileSync(path.join(root,'native-exclusion-universal.cjs')));
 const registry=JSON.parse(fs.readFileSync(path.join(root,'blade-device-registry.json')));
 if(registry.schemaVersion!==1||!Array.isArray(registry.devices)||!registry.devices.length||registry.devices.some(d=>d.vendorId!==0x1532||!Number.isInteger(d.productId)||d.productId<1||d.productId>65535))throw Error('Invalid Blade registry');
 changed.set('blade-device-registry.json',Buffer.from(JSON.stringify(registry,null,2)+'\n'));
 const payload=[archive.subarray(base)];let offset=payload[0].length;const changes=[];
 for(const [name,data] of changed){if(name.endsWith('.json'))JSON.parse(data.toString());else new vm.Script(data.toString(),{filename:name});const parts=name.split('/');let parent=header;for(const p of parts.slice(0,-1)){parent.files[p]??={files:{}};parent=parent.files[p];}const old=parent.files[parts.at(-1)],blockSize=old?.integrity?.blockSize||4194304,blocks=[];for(let i=0;i<data.length;i+=blockSize)blocks.push(sha(data.subarray(i,i+blockSize)));parent.files[parts.at(-1)]={...(old||{}),size:data.length,offset:String(offset),integrity:{algorithm:'SHA256',hash:sha(data),blockSize,blocks}};payload.push(data);offset+=data.length;changes.push({path:name,beforeSha256:old?sha(Buffer.from(original(name))):null,afterSha256:sha(data)});}
 const json=Buffer.from(JSON.stringify(header)),aligned=Math.ceil(json.length/4)*4,prefix=Buffer.alloc(16+aligned);prefix.writeUInt32LE(4,0);prefix.writeUInt32LE(8+aligned,4);prefix.writeUInt32LE(4+aligned,8);prefix.writeUInt32LE(json.length,12);json.copy(prefix,16);
 const result=Buffer.concat([prefix,...payload]),newBase=8+result.readUInt32LE(4),newHeader=JSON.parse(result.subarray(16,16+result.readUInt32LE(12)));let verified=0;
 for(const {path:name,entry:e} of files){if(e.unpacked||e.link||changed.has(name))continue;let n=newHeader;for(const p of name.split('/'))n=n.files[p];const a=archive.subarray(base+Number(e.offset),base+Number(e.offset)+e.size),b=result.subarray(newBase+Number(n.offset),newBase+Number(n.offset)+n.size);if(!a.equals(b))throw Error('Untouched file changed: '+name);verified++;}
 return {result,changed,report:{schemaVersion:1,patchId:'OSSBlade/synapse-blade-blocker',originalAsarSha256:sha(archive),patchedAsarSha256:sha(result),bladeProductIds:[...new Set(registry.devices.map(d=>d.productId))].sort((a,b)=>a-b),untouchedPackedFilesVerified:verified,changes,installedFilesModified:false,appLaunched:false}};
}
function prepare(source,executable,output){
 if(fs.existsSync(output))throw Error('Output already exists; preserve previous preparation');
 const archive=fs.readFileSync(source),exeHash=sha(fs.readFileSync(executable)),built=transform(archive);
 fs.mkdirSync(output,{recursive:true});fs.writeFileSync(path.join(output,'original.asar'),archive,{flag:'wx'});fs.writeFileSync(path.join(output,'blocked.asar'),built.result,{flag:'wx'});
 for(const [name,data] of built.changed){const dest=path.join(output,'patched-blades',name);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,data,{flag:'wx'});}
 Object.assign(built.report,{executableSha256:exeHash,preparedAtUtc:new Date().toISOString()});fs.writeFileSync(path.join(output,'preparation.json'),JSON.stringify(built.report,null,2),{flag:'wx'});return built.report;
}
module.exports={transform,prepare};
if(require.main===module){try{const [source,executable,output]=process.argv.slice(2);if(!source||!executable||!output)throw Error('Usage: node build-prototype-blades.cjs ORIGINAL_ASAR EXECUTABLE NEW_OUTPUT_DIRECTORY');console.log(JSON.stringify(prepare(source,executable,output),null,2));}catch(error){require('./failure-report.cjs').report({stage:'Build',error,archive:process.argv[2],executable:process.argv[3],psVersion:process.env.BLOCKER_POWERSHELL_VERSION});process.exitCode=1;}}
