'use strict';
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const issueUrl='https://github.com/OSSBlade/synapse-blade-blocker/issues/new';
function hash(file){try{return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');}catch{return 'unavailable';}}
function describe(error){
 const text=String(error?.message??error??'');
 const anchor=/Mandatory patch anchor missing or ambiguous \(([a-zA-Z0-9_-]+); matches=(\d+)\)/.exec(text);
 if(anchor)return {category:'incompatible-layout',message:'A mandatory structural edit could not be completed.',anchor:anchor[1],matches:Number(anchor[2])};
 if(/Already patched/.test(text))return {category:'already-patched-source',message:'Preparation requires the preserved original archive.'};
 if(/No matching local preparation/i.test(text))return {category:'missing-input',message:'A required installation file or matching local preparation was unavailable.'};
 if(/hash|integrity|verification|changed|unknown|match|rollback/i.test(text))return {category:'integrity-or-state-mismatch',message:'The observed installation or local archive did not match the required state.'};
 if(/Unsupported input|Invalid ASAR|electronAction handler|Invalid Blade registry/.test(text))return {category:'incompatible-layout',message:'A required archive entry or structural contract was not recognized.'};
 if(/administrator|stopped|Exit Synapse|running|permission|denied|EACCES|EPERM/i.test(text))return {category:'access-or-running-process',message:'Required file access or stopped-process conditions were not satisfied.'};
 if(/ENOENT|not found|Cannot find|No standard|No matching local preparation|does not exist/i.test(text))return {category:'missing-input',message:'A required installation file or matching local preparation was unavailable.'};
 return {category:'operation-failed',message:'The operation stopped. Raw exception text is omitted to protect local paths and identifiers.'};
}
function render({stage,error,archive,executable,psVersion}){
 const safeStage=['Prepare','Build','Apply','Restore','Status'].includes(stage)?stage:'Unknown';
 const version=/[\\/]app-(\d+(?:\.\d+){1,3})[\\/]/.exec(String(executable))?.[1]??'unavailable';
 const detail=describe(error),toolVersion=JSON.parse(fs.readFileSync(path.join(__dirname,'package.json'))).version;
 const safePs=/^\d+(\.\d+){1,3}$/.test(psVersion??'')?psVersion:'unavailable';
 return ['### Synapse Blade Blocker diagnostic','',`- Tool version: ${toolVersion}`,'- Patch contract: OSSBlade/synapse-blade-blocker (schema 1)',`- Stage: ${safeStage}`,`- AppEngine version: ${version}`,`- Archive SHA-256: ${hash(archive)}`,`- Executable SHA-256: ${hash(executable)}`,`- Error category: ${detail.category}`,`- Message: ${detail.message}`,...(detail.anchor?[`- Anchor: ${detail.anchor}`,`- Anchor matches: ${detail.matches}`]:[]),`- OS: ${process.platform} ${os.release()} ${process.arch}`,`- Node: ${process.versions.node}`,`- PowerShell: ${safePs}`,'','No archive content, native code, device serials, usernames, or local paths are included.','',`Report this result: ${issueUrl}`,''].join('\n');
}
function report(options,outputDirectory=path.join(__dirname,'diagnostics')){
 let markdown;try{markdown=render(options);}catch{markdown='Synapse Blade Blocker operation failed. Diagnostic generation was unavailable.\nReport: '+issueUrl+'\n';}
 try{fs.mkdirSync(outputDirectory,{recursive:true});const name=path.join(outputDirectory,'failure-'+new Date().toISOString().replace(/[:.]/g,'-')+'-'+crypto.randomUUID()+'.md');fs.writeFileSync(name,markdown,{flag:'wx'});console.error('Sanitized issue report saved: '+name);}catch{console.error('Could not save the diagnostic file; copy the report below.');}
 console.error(markdown);return markdown;
}
module.exports={describe,render,report};
if(require.main===module){const options={};for(const arg of process.argv.slice(2)){const match=/^--(stage|error|archive|executable|psVersion)=(.*)$/s.exec(arg);if(match)options[match[1]]=match[2];}report(options);}
