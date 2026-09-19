'use strict';
const fs=require('node:fs'),path=require('node:path');
const base=path.join(__dirname,'prepared');
const root=process.env.BLOCKER_PREPARATION_DIRECTORY || (fs.existsSync(base)?fs.readdirSync(base).sort().reverse().map(n=>path.join(base,n)).find(n=>fs.existsSync(path.join(n,'preparation.json'))):null);
if(!root)throw Error('Run Prepare.ps1 first or set BLOCKER_PREPARATION_DIRECTORY to a successful preparation.');
module.exports=root;
