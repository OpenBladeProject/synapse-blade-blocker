'use strict';
const path=require('node:path'),{verifyPreparation}=require('./preparation-identity.cjs');
const selected=process.env.BLOCKER_PREPARATION_DIRECTORY;
if(!selected)throw Error('Set BLOCKER_PREPARATION_DIRECTORY to a preparation created by this package before running local module tests.');
const root=path.resolve(selected);
if(!verifyPreparation(root))throw Error('BLOCKER_PREPARATION_DIRECTORY is stale or failed integrity verification. Run Prepare.ps1 with this package and select the new preparation.');
module.exports=root;
