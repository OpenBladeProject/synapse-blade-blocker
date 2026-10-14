'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');

const sourceFiles=[
 'build-prototype-blades.cjs',
 'preparation-identity.cjs',
 'device-exclusion-universal.cjs',
 'native-exclusion-universal.cjs',
 'blade-device-registry.json'
];
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function addFrame(hash,bytes){const length=Buffer.alloc(8);length.writeBigUInt64BE(BigInt(bytes.length));hash.update(length);hash.update(bytes);}
function sourceIdentity(root=__dirname){
 const hash=crypto.createHash('sha256');
 for(const relativePath of sourceFiles){addFrame(hash,Buffer.from(relativePath,'utf8'));addFrame(hash,fs.readFileSync(path.join(root,relativePath)));}
 return hash.digest('hex');
}
function verifyPreparation(directory){
 try{
  const manifest=JSON.parse(fs.readFileSync(path.join(directory,'preparation.json'),'utf8'));
  if(!/^[a-f0-9]{64}$/.test(manifest.patchSourceSha256||'')||manifest.patchSourceSha256!==sourceIdentity())return false;
  if(!/^[a-f0-9]{64}$/.test(manifest.originalAsarSha256||'')||!/^[a-f0-9]{64}$/.test(manifest.patchedAsarSha256||''))return false;
  const original=fs.readFileSync(path.join(directory,'original.asar')),blocked=fs.readFileSync(path.join(directory,'blocked.asar'));
  if(sha(original)!==manifest.originalAsarSha256||sha(blocked)!==manifest.patchedAsarSha256)return false;
  const built=require('./build-prototype-blades.cjs').transform(original);
  if(sha(built.result)!==manifest.patchedAsarSha256||!built.result.equals(blocked))return false;
  for(const [name,bytes] of built.changed){if(!fs.readFileSync(path.join(directory,'patched-blades',...name.split('/'))).equals(bytes))return false;}
  return true;
 }catch{return false;}
}

module.exports={sourceFiles,sourceIdentity,verifyPreparation};
if(require.main===module){
 const [command,argument,...extra]=process.argv.slice(2);
 if(command==='--source-identity'&&argument===undefined){process.stdout.write(sourceIdentity()+'\n');}
 else if(command==='--verify-preparation'&&argument&&extra.length===0){process.stdout.write(JSON.stringify(verifyPreparation(argument))+'\n');}
 else{process.stderr.write('Usage: node preparation-identity.cjs --source-identity | --verify-preparation DIRECTORY\n');process.exitCode=2;}
}
