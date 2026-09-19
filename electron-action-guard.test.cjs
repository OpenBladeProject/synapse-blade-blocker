'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),{test}=require('node:test');
const root=__dirname,source=fs.readFileSync(path.join(root,'patched-blades/electron/main.js'),'utf8');
const policy=require('./patched-blades/openblade-native-exclusion.cjs');
const anchor='n.handle("electronAction",',start=source.indexOf(anchor)+anchor.length;
assert(start>=anchor.length);let factory,end=start;
while((end=source.indexOf('}',end+1))>=0){try{factory=new Function('no','D','obNativeExclusion','return ('+source.slice(start,end+1)+');');break;}catch(e){if(!(e instanceof SyntaxError))throw e;}}
assert(factory);
const a=fs.readFileSync(path.join(root,'original.asar')),h=JSON.parse(a.subarray(16,16+a.readUInt32LE(12))),entry=h.files.electron.files['constants.js'],offset=8+a.readUInt32LE(4)+Number(entry.offset);
const match=/module\.exports\.actionEnum=(\{[^}]+\})/.exec(a.subarray(offset,offset+entry.size).toString());assert(match);
const D=vm.runInNewContext('('+match[1]+')',{}, {timeout:100});
function fixture(){const calls=[];return{calls,fn:factory({callDLL(e,r){calls.push(r);return 'forwarded';}},D,policy)};}
const sender=(url,frame=url)=>({sender:{getURL:()=>url},senderFrame:{url:frame}});
const blade='https://apps.razer.com/synapse/products/736/ui/',shared='https://apps.razer.com/background-manager/',peripheral='https://apps.razer.com/synapse/products/3907/mw/';
for(const action of ['toggleTouchPadEnableStatus','systemSKU','getTouchPadEnableStatus'])test('actual native dispatch rejects Blade '+action,async()=>{const f=fixture();await assert.rejects(f.fn(sender(blade),{action}),e=>e.code==='OPENBLADE_NATIVE_DEVICE_EXCLUDED');assert.equal(f.calls.length,0);});
test('Blade child frame rejected in shared window',async()=>{const f=fixture();await assert.rejects(f.fn(sender(shared,blade),{action:'toggleTouchPadEnableStatus'}),e=>e.code==='OPENBLADE_NATIVE_DEVICE_EXCLUDED');assert.equal(f.calls.length,0);});
for(const origin of [shared,peripheral])test('common OS utilities preserved for '+origin,async()=>{const f=fixture();for(const action of ['keyboardLayout','getMonitorInfo','computerName'])assert.equal(await f.fn(sender(origin),{action}),'forwarded');assert.equal(f.calls.length,3);});
test('shared touchpad route remains an explicit unresolved isolation gap',async()=>{const f=fixture();assert.equal(await f.fn(sender(shared),{action:'toggleTouchPadEnableStatus'}),'forwarded');assert.equal(f.calls.length,1);});
test('non-native version query remains available to Blade pages',async()=>{const f=fixture();assert.equal(await f.fn(sender(blade),{action:'process.versions'}),process.versions);assert.equal(f.calls.length,0);});
