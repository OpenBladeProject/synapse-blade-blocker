$ErrorActionPreference='Stop'
function Assert($Condition,[string]$Message){if(!$Condition){throw $Message}}

$scratch=Join-Path ([IO.Path]::GetTempPath()) ('blocker-native-process-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
try{
 $package=Join-Path $scratch 'package'
 New-Item -ItemType Directory -Path $package | Out-Null
 foreach($file in @('Blocker.Common.ps1','Prepare.ps1','build-prototype-blades.cjs','failure-report.cjs','inspect-archive.cjs','package.json','device-exclusion-universal.cjs','native-exclusion-universal.cjs','blade-device-registry.json')){
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $package
 }
 $nativeFixture=Join-Path $scratch 'native-stderr.cjs'
 [IO.File]::WriteAllText($nativeFixture,"process.stdout.write('stdout-fixture\n');process.stderr.write('stderr-fixture-'+process.argv[2]+'\n');process.exitCode=Number(process.argv[2]);")

 function Invoke-HostlessNode([int]$ExitCode,[switch]$DiscardStandardError){
  $powershell=[PowerShell]::Create()
  try{
   $script={
    param($Package,$Fixture,$RequestedExit,$Discard)
    $ErrorActionPreference='Stop'
    . (Join-Path $Package 'Blocker.Common.ps1')
    $before=[string]$ErrorActionPreference
    $process=Invoke-BlockerNode -Arguments @($Fixture,[string]$RequestedExit) -DiscardStandardError:$Discard
    [pscustomobject]@{NativeExitCode=$process.ExitCode;NativeOutput=($process.Output -join '|');Before=$before;After=[string]$ErrorActionPreference;ReachedAfter=$true}
   }
   [void]$powershell.AddScript($script.ToString()).AddArgument($package).AddArgument($nativeFixture).AddArgument($ExitCode).AddArgument([bool]$DiscardStandardError)
   $handle=$powershell.BeginInvoke()
   $output=@($powershell.EndInvoke($handle))
   [pscustomobject]@{Result=($output | Select-Object -Last 1);Errors=@($powershell.Streams.Error)}
  }finally{$powershell.Dispose()}
 }

 foreach($exitCode in @(0,7)){
  $case=Invoke-HostlessNode $exitCode
  Assert ($case.Result.ReachedAfter -and $case.Result.NativeExitCode -eq $exitCode) "Hostless Node exit $exitCode terminated before exit-code capture"
  Assert ($case.Result.NativeOutput -ceq 'stdout-fixture') "Hostless Node exit $exitCode lost stdout"
  Assert ($case.Result.Before -eq 'Stop' -and $case.Result.After -eq 'Stop') "Hostless Node exit $exitCode did not restore ErrorActionPreference"
  Assert ($case.Errors.Count -eq 1 -and [string]$case.Errors[0] -match "stderr-fixture-$exitCode") "Hostless Node exit $exitCode did not retain stderr"
 }
 $discarded=Invoke-HostlessNode 0 -DiscardStandardError
 Assert ($discarded.Result.ReachedAfter -and $discarded.Errors.Count -eq 0) 'DiscardStandardError did not suppress hostless native stderr'
 Assert ($ErrorActionPreference -eq 'Stop') 'Hostless helper changed the caller ErrorActionPreference'

 # Run the real preparation failure path against an incompatible scratch archive.
 $programFiles=Join-Path $scratch 'ProgramFiles'
 $install=Join-Path $programFiles 'Razer\RazerAppEngine\app-99.1.0'
 New-Item -ItemType Directory -Path (Join-Path $install 'resources') -Force | Out-Null
 [IO.File]::WriteAllText((Join-Path $install 'resources\app.asar'),'incompatible archive fixture')
 [IO.File]::WriteAllText((Join-Path $install 'RazerAppEngine.exe'),'fixture executable')
 $powershell=[PowerShell]::Create()
 try{
  $script={
   param($Package,$ProgramFiles,$Install)
   $ErrorActionPreference='Stop'
   $oldProgramFiles=$env:ProgramFiles
   try{
    $env:ProgramFiles=$ProgramFiles
    $items=@(& (Join-Path $Package 'Prepare.ps1') -InstallDirectory $Install)
    [pscustomobject]@{Caught=$false;PreparedCount=@($items | Where-Object {$_.Prepared -eq $true}).Count;After=[string]$ErrorActionPreference}
   }catch{
    [pscustomobject]@{Caught=$true;PreparedCount=0;Message=$_.Exception.Message;After=[string]$ErrorActionPreference}
   }finally{$env:ProgramFiles=$oldProgramFiles}
  }
  [void]$powershell.AddScript($script.ToString()).AddArgument($package).AddArgument($programFiles).AddArgument($install)
  $handle=$powershell.BeginInvoke()
  $prepareResult=@($powershell.EndInvoke($handle)) | Select-Object -Last 1
  Assert ($prepareResult.Caught -and $prepareResult.PreparedCount -eq 0) 'Incompatible preparation reported success'
  Assert ($prepareResult.Message -match '^Preparation failed\.') 'Incompatible preparation lost its stable failure message'
  Assert ($prepareResult.After -eq 'Stop') 'Preparation failure did not restore ErrorActionPreference'
 }finally{$powershell.Dispose()}
 $reports=@(Get-ChildItem -LiteralPath (Join-Path $package 'diagnostics') -Filter '*.md')
 Assert ($reports.Count -eq 1) 'A single failing builder did not produce exactly one diagnostic report'
 Assert (@(Get-ChildItem -LiteralPath (Join-Path $package 'prepared') -Filter 'preparation.json' -Recurse -ErrorAction SilentlyContinue).Count -eq 0) 'Incompatible preparation left success metadata'

 # A benign Node preload warning must not turn valid archive inspection into Unreadable.
 $archive=Join-Path $scratch 'valid-original.asar'
 $archiveBuilder=Join-Path $scratch 'make-archive.cjs'
 $archiveSource=@"
const fs=require('node:fs');
const names=['node_modules/rz-usb-detect/index.js','node_modules/node-rz-hid/nodehid.js','electron/main.js','electron/modules/mapping_engine/win/index.js'];
const h={files:{}},data=[];let offset=0;
for(const name of names){const bytes=Buffer.from('module.exports={};'),parts=name.split('/');let dir=h;for(const part of parts.slice(0,-1))dir=dir.files[part]??={files:{}};dir.files[parts.at(-1)]={size:bytes.length,offset:String(offset)};data.push(bytes);offset+=bytes.length;}
const json=Buffer.from(JSON.stringify(h)),aligned=Math.ceil(json.length/4)*4,header=Buffer.alloc(16+aligned);header.writeUInt32LE(4,0);header.writeUInt32LE(8+aligned,4);header.writeUInt32LE(4+aligned,8);header.writeUInt32LE(json.length,12);json.copy(header,16);fs.writeFileSync(process.argv[2],Buffer.concat([header,...data]));
"@
 [IO.File]::WriteAllText($archiveBuilder,$archiveSource)
 $nodeSource=(Microsoft.PowerShell.Core\Get-Command node -CommandType Application | Select-Object -First 1).Source
 & $nodeSource $archiveBuilder $archive
 Assert ($LASTEXITCODE -eq 0) 'Synthetic inspection archive construction failed'
 $sha=[Security.Cryptography.SHA256]::Create()
 try{$archiveHash=[BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($archive))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
 $warningFixture=Join-Path $scratch 'preload-warning.cjs'
 [IO.File]::WriteAllText($warningFixture,"process.stderr.write('benign preload warning\n');")
 $powershell=[PowerShell]::Create()
 try{
  $script={
   param($Package,$Archive,$ExpectedHash,$WarningFixture)
   $ErrorActionPreference='Stop'
   $oldNodeOptions=$env:NODE_OPTIONS
   try{
    $env:NODE_OPTIONS='--require="'+($WarningFixture -replace '\\','/')+'"'
    . (Join-Path $Package 'Blocker.Common.ps1')
    $inspection=Get-ArchiveInspection $Archive $ExpectedHash
    [pscustomobject]@{State=$inspection.State;After=[string]$ErrorActionPreference}
   }finally{$env:NODE_OPTIONS=$oldNodeOptions}
  }
  [void]$powershell.AddScript($script.ToString()).AddArgument($package).AddArgument($archive).AddArgument($archiveHash).AddArgument($warningFixture)
  $handle=$powershell.BeginInvoke()
  $inspectionResult=@($powershell.EndInvoke($handle)) | Select-Object -Last 1
  Assert ($inspectionResult.State -eq 'NoPatchDetected') 'Benign Node stderr made a valid archive unreadable'
  Assert ($inspectionResult.After -eq 'Stop' -and $powershell.Streams.Error.Count -eq 0) 'Archive inspection leaked discarded stderr or changed ErrorActionPreference'
 }finally{$powershell.Dispose()}

 Write-Output ('Passed native hostless-process regression tests in PowerShell '+$PSVersionTable.PSVersion+'.')
}finally{
 $resolved=[IO.Path]::GetFullPath($scratch)
 $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
 if(!$resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notlike 'blocker-native-process-*'){throw 'Unsafe scratch cleanup path'}
 Remove-Item -LiteralPath $resolved -Recurse -Force
}
