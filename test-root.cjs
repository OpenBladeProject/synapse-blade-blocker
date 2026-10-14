'use strict';
const fs=require('node:fs'),path=require('node:path');
const bases=[...(process.env.LOCALAPPDATA?[path.join(process.env.LOCALAPPDATA,'SynapseBladeBlocker','Backups')]:[]),path.join(__dirname,'prepared')];
const root=process.env.BLOCKER_PREPARATION_DIRECTORY || bases.flatMap(base=>fs.existsSync(base)?fs.readdirSync(base).sort().reverse().map(n=>path.join(base,n)):[]).find(n=>fs.existsSync(path.join(n,'preparation.json')));
if(!root)throw Error('Run Prepare.ps1 first or set BLOCKER_PREPARATION_DIRECTORY to a successful preparation.');
module.exports=root;
