'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),{test}=require('node:test');
const root=require('./test-root.cjs'),source=fs.readFileSync(path.join(root,'patched-blades/electron/main.js'),'utf8');
const policy=require(require('./test-root.cjs')+'/patched-blades/openblade-native-exclusion.cjs');
const anchor=/[A-Za-z_$][\w$]*\.handle\("electronAction",/.exec(source)?.[0];assert(anchor);const start=source.indexOf(anchor)+anchor.length;
assert(start>=anchor.length);let factory,end=start;
const nativeAlias=/assertAllowed\("electronAction",[$\w]+,[$\w]+\),([$\w]+)\.callDLL/.exec(source)[1];
const serviceAliases=['StartService','StopService','GetServiceStatus'].map(action=>new RegExp('case"'+action+'":return obNativeExclusion\\.assertAllowed\\("electronAction",[$\\w]+,[$\\w]+\\),([$\\w]+)\\(([$\\w]+),').exec(source));
while((end=source.indexOf('}',end+1))>=0){try{factory=new Function(nativeAlias,'D','obNativeExclusion',...serviceAliases.map(m=>m[1]),serviceAliases[0][2],'return ('+source.slice(start,end+1)+');');break;}catch(e){if(!(e instanceof SyntaxError))throw e;}}
assert(factory);
const a=fs.readFileSync(path.join(root,'original.asar')),h=JSON.parse(a.subarray(16,16+a.readUInt32LE(12))),entry=h.files.electron.files['constants.js'],offset=8+a.readUInt32LE(4)+Number(entry.offset);
const match=/module\.exports\.actionEnum=(\{[^}]+\})/.exec(a.subarray(offset,offset+entry.size).toString());assert(match);
const D=vm.runInNewContext('('+match[1]+')',{}, {timeout:100});
function fixture(){const calls=[],record=async(_native,r)=>{calls.push(r);return 'forwarded'};return {calls,fn:factory({},D,policy,record,record,record,{})};}
const blade='https://apps.razer.com/synapse/products/736/ui/',shared='https://apps.razer.com/background-manager/',peripheral='https://apps.razer.com/synapse/products/3907/mw/';
const sender=(url,frame=url)=>({sender:{getURL:()=>url},senderFrame:{url:frame}});
for(const action of ['StartService','StopService','GetServiceStatus']){
 for(const [label,event] of [['Blade page',sender(blade)],['Blade frame',sender(shared,blade)]])test(action+' rejects '+label,async()=>{const f=fixture();await assert.rejects(f.fn(event,{action,payload:{actionArgs:['INERT_AUDIT_SERVICE']}}),e=>e.code==='OPENBLADE_NATIVE_DEVICE_EXCLUDED');assert.equal(f.calls.length,0)});
 for(const [label,event] of [['shared',sender(shared)],['peripheral',sender(peripheral)]])test(action+' preserves '+label+' route',async()=>{const f=fixture(),r={action,payload:{actionArgs:['INERT_AUDIT_SERVICE']}};assert.equal(await f.fn(event,r),'forwarded');assert.deepEqual(f.calls,[r])});
}
