'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{execFileSync}=require('node:child_process');

test('local module tests find durable backups after moving the package and retain legacy and explicit selection',t=>{
 const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'blocker-test-root-'));
 t.after(()=>fs.rmSync(scratch,{recursive:true,force:true}));
 const moved=path.join(scratch,'new-package'),local=path.join(scratch,'local-appdata');
 fs.mkdirSync(moved);fs.copyFileSync(path.join(__dirname,'test-root.cjs'),path.join(moved,'test-root.cjs'));
 const script=path.join(moved,'test-root.cjs');
 function choose(extra={}){return execFileSync(process.execPath,['-e','process.stdout.write(require(process.argv[1]))',script],{env:{...process.env,LOCALAPPDATA:local,BLOCKER_PREPARATION_DIRECTORY:'',...extra},encoding:'utf8'});}
 const legacy=path.join(moved,'prepared','older');fs.mkdirSync(legacy,{recursive:true});fs.writeFileSync(path.join(legacy,'preparation.json'),'{}');
 assert.equal(choose(),legacy);
 const durable=path.join(local,'SynapseBladeBlocker','Backups','saved');fs.mkdirSync(durable,{recursive:true});fs.writeFileSync(path.join(durable,'preparation.json'),'{}');
 assert.equal(choose(),durable);
 assert.equal(choose({BLOCKER_PREPARATION_DIRECTORY:legacy}),legacy);
 fs.rmSync(path.join(moved,'prepared'),{recursive:true});
 assert.equal(choose(),durable);
});
