'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=__dirname,MAX_ARCHIVE_BYTES=1024*1024*1024,MAX_HEADER_BYTES=32*1024*1024;
const sha=value=>crypto.createHash('sha256').update(value).digest('hex');
const helperPaths=['openblade-device-exclusion.cjs','openblade-native-exclusion.cjs','blade-device-registry.json'];
const corePaths=['node_modules/rz-usb-detect/index.js','node_modules/node-rz-hid/nodehid.js','electron/main.js','electron/modules/mapping_engine/win/index.js'];
const currentHelpers=new Map([
 [helperPaths[0],sha(fs.readFileSync(path.join(root,'device-exclusion-universal.cjs')))],
 [helperPaths[1],sha(fs.readFileSync(path.join(root,'native-exclusion-universal.cjs')))],
 [helperPaths[2],sha(Buffer.from(JSON.stringify(JSON.parse(fs.readFileSync(path.join(root,'blade-device-registry.json'))),null,2)+'\n'))]
]);
// Fingerprints of our preserved pre-release helper modules (not vendor builds).
// The first profile precedes the device-event observation update; the second
// retains the earlier registry serialization. Both require matching hooks.
const legacyHelperProfiles=[
 ['452c88ebec9bf2ee7945d303519fcec265d53f87ed56a2cf4f1adbc53566e8b4','c8b60cdf375fe88e665ac45b06bf95a1004def0ea4f54daafb74e5b8e78c53af','ee5e0fad6d12d2ecf2b5c6f0fd8f6431eb0e0c36a950234c443617aa0b00c69b'],
 ['1128593baaa2bb0e93248efb5289bb7b641ac62cc1da94d53467673d44166c17','c8b60cdf375fe88e665ac45b06bf95a1004def0ea4f54daafb74e5b8e78c53af','ee5e0fad6d12d2ecf2b5c6f0fd8f6431eb0e0c36a950234c443617aa0b00c69b']
];
const traceTokens=['openblade-device-exclusion.cjs','openblade-native-exclusion.cjs','obExclusion.visibleDevices','obExclusion.observeDevice','obExclusion.blockedDevice','obExclusion.rejectOpen','obNativeExclusion.assertAllowed','obDeviceExclusion.blockedDevice','OPENBLADE_DEVICE_EXCLUDED','OPENBLADE_NATIVE_DEVICE_EXCLUDED'];
const count=(text,token)=>text.split(token).length-1;
function result(State,ArchiveSha256,Evidence){return {State,ArchiveSha256,Evidence};}
function parse(archive){
 if(archive.length<16||archive.readUInt32LE(0)!==4)throw Error('prefix');
 const headerLength=archive.readUInt32LE(12),headerSpace=archive.readUInt32LE(4),base=8+headerSpace;
 if(headerLength<2||headerLength>MAX_HEADER_BYTES||headerSpace<8||headerSpace%4!==0||archive.readUInt32LE(8)+4!==headerSpace||headerLength>headerSpace-8||16+headerLength>archive.length||base>archive.length)throw Error('header bounds');
 const header=JSON.parse(archive.subarray(16,16+headerLength).toString('utf8'));
 if(!header||typeof header!=='object'||!header.files||typeof header.files!=='object')throw Error('header shape');
 function entry(name,required=false){
  let node=header;
  for(const part of name.split('/')){if(!node.files||!Object.hasOwn(node.files,part)){if(required)throw Error('required entry');return null;}node=node.files[part];}
  if(!node||node.files||node.unpacked||node.link)throw Error('entry shape');
  if(typeof node.offset!=='string'||!/^\d+$/.test(node.offset))throw Error('entry offset');
  const offset=Number(node.offset),size=node.size;
  if(!Number.isSafeInteger(offset)||offset<0||!Number.isSafeInteger(size)||size<0||base+offset>archive.length-size)throw Error('entry bounds');
  return archive.subarray(base+offset,base+offset+size);
 }
 return {entry};
}
function wrappersComplete(text){
 const usb=text.get(corePaths[0]),hid=text.get(corePaths[1]),mapping=text.get(corePaths[3]);
 return usb.startsWith("var obExclusion = require('../../openblade-device-exclusion.cjs');\n")
  &&count(usb,'devices = obExclusion.visibleDevices(devices, !err);')===1&&count(usb,'obExclusion.observeDevice(device); if (obExclusion.blockedDevice(device)) return;')===2
  &&hid.startsWith("var obExclusion = require('../../openblade-device-exclusion.cjs');\n")
  &&count(hid,'function HID() {\n    obExclusion.rejectOpen(arguments);')===1&&count(hid,'return obExclusion.visibleDevices(binding.devices.apply(HID,arguments));')===1
  &&mapping.startsWith('const obDeviceExclusion=require("../../../../openblade-device-exclusion.cjs");\n')
  &&[...mapping.matchAll(/if\(([$\w]+)&&!obDeviceExclusion\.blockedDevice\(\1\)\)\{/g)].length===1;
}
function mainProfile(text){
 const main=text.get(corePaths[2]),direct=['ffiPreload','ffiPreloadAsync','ffiSubPreloadAsync','mappingEngineAction'],braced=['simpleServiceAction','lightingDriver'];
 const directRoutes=direct.every(route=>[...main.matchAll(new RegExp('\\.handle\\("'+route+'",(?:async)?\\([^)]*\\)=>\\(obNativeExclusion\\.assertAllowed\\("'+route+'",[^)]*\\),[$\\w]+\\.callDLL(?:Async)?\\(','g'))].length===1);
 const bracedRoutes=braced.every(route=>[...main.matchAll(new RegExp('\\.handle\\("'+route+'",async\\([^)]*\\)=>\\{obNativeExclusion\\.assertAllowed\\("'+route+'",[^;]*\\);','g'))].length===1);
 const electron=[...main.matchAll(/return obNativeExclusion\.assertAllowed\("electronAction",[$\w]+,[$\w]+\),[$\w]+\.callDLL\(/g)].length;
 const services=['GetServiceStatus','StartService','StopService'].map(action=>[...main.matchAll(new RegExp('case"'+action+'":return obNativeExclusion\\.assertAllowed\\("electronAction",[$\\w]+,[$\\w]+\\),[$\\w]+\\([$\\w]+,[$\\w]+\\);','g'))].length);
 const ownRequire=main.startsWith('const obNativeExclusion=require("../openblade-native-exclusion.cjs");\n');
 const base=directRoutes&&bracedRoutes;
 return {legacy:ownRequire&&base&&(electron===0||electron===1)&&services.every(n=>n===0),current:ownRequire&&base&&electron===1&&services.every(n=>n===1)};
}
function inspectArchive(archivePath){
 let archive,archiveSha256=null;
 try{
  const stat=fs.statSync(archivePath);if(!stat.isFile()||stat.size<16||stat.size>MAX_ARCHIVE_BYTES)throw Error('file bounds');
  archive=fs.readFileSync(archivePath);archiveSha256=sha(archive);
  const parsed=parse(archive),core=new Map(corePaths.map(name=>[name,parsed.entry(name,true)]));
  const helpers=new Map(helperPaths.map(name=>[name,parsed.entry(name)]));
  const text=new Map([...core,...helpers].filter(([,bytes])=>bytes).map(([name,bytes])=>[name,bytes.toString('utf8')]));
  const recognized=[...helpers.values()].some(Boolean)||[...text.values()].some(source=>traceTokens.some(token=>source.includes(token)));
  if(!recognized)return result('NoPatchDetected',archiveSha256,['Required application modules are present; no recognized blocker traces were detected.']);
  const helperHashes=helperPaths.map(name=>helpers.get(name)&&sha(helpers.get(name)));
  const allHelpers=helperHashes.every(Boolean),wrappers=wrappersComplete(text),profile=mainProfile(text);
  const current=allHelpers&&helperPaths.every((name,index)=>helperHashes[index]===currentHelpers.get(name));
  if(current&&wrappers&&profile.current)return result('CurrentPatch',archiveSha256,['Current blocker helper modules match packaged bytes.','All required blocker call sites are present.']);
  const legacy=allHelpers&&legacyHelperProfiles.some(expected=>expected.every((hash,index)=>hash===helperHashes[index]));
  if(legacy&&wrappers&&(profile.legacy||profile.current))return result('LegacyPatch',archiveSha256,['A known legacy blocker helper and call-site profile was detected.']);
  return result('PartialPatch',archiveSha256,['Recognized blocker traces are incomplete or do not match a known complete patch.']);
 }catch{return result('Unreadable',archiveSha256,['The archive structure could not be inspected safely.']);}
}
module.exports={inspectArchive};
if(require.main===module){const archivePath=process.argv[2];console.log(JSON.stringify(archivePath?inspectArchive(archivePath):result('Unreadable',null,['An archive path is required.'])));}
