$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'BladeBlocker.Desktop.ps1')
function Assert($Condition,[string]$Message){if(!$Condition){throw $Message}}
function Throws([scriptblock]$Action,[string]$Message){$failed=$false;try{& $Action | Out-Null}catch{$failed=$true};Assert $failed $Message}

# Each action must require fresh, usable input; stale marker data never grants restore.
$a=Get-DesktopActions 'Original' $false $true $true $true $true $false 'NoPatchDetected'
Assert ($a.CanPatch -and !$a.CanRestore) 'Verified original should permit Patch only'
$a=Get-DesktopActions 'Experimental blocker applied' $true $true $false $false $true $false 'NoPatchDetected'
Assert ($a.CanRestore -and !$a.CanPatch) 'Restore must work without Node or the patched source'
$a=Get-DesktopActions 'Experimental blocker applied' $true $false $true $true $true $false 'NoPatchDetected'
Assert (!$a.CanRestore) 'Missing original enabled Restore'
$a=Get-DesktopActions 'No matching preparation' $true $false $false $true $true $false 'NoPatchDetected'
Assert (!$a.CanPrepare -and !$a.CanPatch -and !$a.CanRestore) 'Applied marker without original permitted mutation'
$a=Get-DesktopActions 'No matching preparation' $false $false $false $true $true $true 'NoPatchDetected'
Assert (!$a.CanPrepare -and !$a.CanPatch) 'Mismatched selected preparation was silently replaced'
$a=Get-DesktopActions 'No matching preparation' $false $false $false $true $true $false 'NoPatchDetected'
Assert ($a.CanPrepare -and $a.CanPatch -and !$a.CanRestore) 'Fresh original could not be prepared'
foreach($state in @('Unknown archive','Unavailable')){
 $a=Get-DesktopActions $state $false $true $true $true $true $false 'NoPatchDetected'
 Assert (!$a.CanPatch -and !$a.CanRestore) 'Unknown/unavailable archive permitted mutation'
}
foreach($state in @('Original','Experimental blocker applied','No matching preparation')){
 $a=Get-DesktopActions $state $false $true $true $true $false $false 'NoPatchDetected'
 Assert (!$a.CanPatch -and !$a.CanRestore) 'Running controller permitted mutation'
}
foreach($content in @('CurrentPatch','LegacyPatch','PartialPatch','Unreadable')){
 $a=Get-DesktopActions 'Original' $false $true $true $true $true $false $content
 Assert (!$a.CanPatch -and !$a.CanPrepare) 'Content inspection was ignored for an alleged original'
 $a=Get-DesktopActions 'No matching preparation' $false $false $false $true $true $false $content
 Assert (!$a.CanPatch -and !$a.CanPrepare -and !$a.CanRestore) 'Untracked patch permitted preparation or restore'
 $a=Get-DesktopActions 'Experimental blocker applied' $false $true $true $false $true $false $content
 Assert $a.CanRestore 'Independent inspection failure blocked a verified original restore'
}
Assert ((ConvertTo-DesktopArgument "C:\a b\owner's folder\") -ceq '"C:\a b\owner''s folder\\"') 'Trailing slash or apostrophe quoting failed'
foreach($arg in @('a"b',"a`nb","a`rb","a$([char]0)b")){Throws {ConvertTo-DesktopArgument $arg} 'Unsafe argument accepted'}

# Exercise real discovery against synthetic installation files, with two Node paths.
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('blocker-desktop-tests-'+[guid]::NewGuid().ToString('N'))
$originalProgramFiles=$env:ProgramFiles
$nodeSource=(Microsoft.PowerShell.Core\Get-Command node -CommandType Application | Select-Object -First 1).Source
function Get-Command {param($Name,$CommandType,$ErrorAction) if($Name -eq 'node'){@([pscustomobject]@{Source=$nodeSource},[pscustomobject]@{Source='C:\unreachable-second-node.exe'})}}
function Get-Process {param($Name,$ErrorAction)}
function Get-Service {param($Name,$ErrorAction)}
try{
 $env:ProgramFiles=Join-Path $scratch 'ProgramFiles'
 $install=Join-Path $env:ProgramFiles 'Razer\RazerAppEngine\app-99.1.0'
 $prep=Join-Path $scratch 'preparation'
 New-Item -ItemType Directory -Path (Join-Path $install 'resources'),$prep -Force | Out-Null
 $target=Join-Path $install 'resources\app.asar';$exe=Join-Path $install 'RazerAppEngine.exe'
 $fixtureScript=Join-Path $scratch 'make-archive.cjs'
 $fixtureSource=@"
const fs=require('node:fs');
const names=['node_modules/rz-usb-detect/index.js','node_modules/node-rz-hid/nodehid.js','electron/main.js','electron/modules/mapping_engine/win/index.js'];
const h={files:{}},data=[];let offset=0;
for(const name of names){const bytes=Buffer.from('module.exports={};'),parts=name.split('/');let dir=h;for(const part of parts.slice(0,-1))dir=dir.files[part]??={files:{}};dir.files[parts.at(-1)]={size:bytes.length,offset:String(offset)};data.push(bytes);offset+=bytes.length;}
const json=Buffer.from(JSON.stringify(h)),aligned=Math.ceil(json.length/4)*4,header=Buffer.alloc(16+aligned);header.writeUInt32LE(4,0);header.writeUInt32LE(8+aligned,4);header.writeUInt32LE(4+aligned,8);header.writeUInt32LE(json.length,12);json.copy(header,16);fs.writeFileSync(process.argv[2],Buffer.concat([header,...data]));
"@
 [IO.File]::WriteAllText($fixtureScript,$fixtureSource)
 & $nodeSource $fixtureScript $target
 Assert ($LASTEXITCODE -eq 0) 'Synthetic ASAR construction failed'
 [IO.File]::WriteAllText($exe,'future executable')
 Copy-Item -LiteralPath $target -Destination (Join-Path $prep 'original.asar')
 [IO.File]::WriteAllText((Join-Path $prep 'blocked.asar'),'patched fixture')
 $m=[ordered]@{schemaVersion=1;patchId='OSSBlade/synapse-blade-blocker';originalAsarSha256=(Read-Hash $target);patchedAsarSha256=(Read-Hash (Join-Path $prep 'blocked.asar'));executableSha256=(Read-Hash $exe);bladeProductIds=@(736)}
 $m | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $prep 'preparation.json')
 $s=Get-DesktopState $prep $install
 Assert ($s.NodeReady -and $s.State -eq 'Original' -and $s.CanPatch -and !$s.CanRestore -and $s.ContentState -eq 'NoPatchDetected') 'Independent archive inspection or multiple Node resolution failed'
 # A newer installation appearing after Refresh must not redirect a queued action.
 $newer=Join-Path $env:ProgramFiles 'Razer\RazerAppEngine\app-99.2.0'
 New-Item -ItemType Directory -Path (Join-Path $newer 'resources') -Force | Out-Null
 Copy-Item -LiteralPath $target -Destination (Join-Path $newer 'resources\app.asar')
 Copy-Item -LiteralPath $exe -Destination $newer
 Assert ((Resolve-AppEngine '') -eq $newer) 'New installation was not selected by automatic discovery'
 $uiAst=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'BladeBlocker.UI.ps1'),[ref]$null,[ref]$null)
 $dispatchAst=$uiAst.Find({param($node) $node -is [System.Management.Automation.Language.ScriptBlockExpressionAst] -and $node.Extent.Text.Contains('param($Root,$Action,$Preparation,$Installation)')},$true)
 Assert ($null -ne $dispatchAst) 'UI dispatch does not carry the confirmed installation'
 $dispatch=$dispatchAst.ScriptBlock.GetScriptBlock()
 # An explicit missing preparation guarantees no write admission or elevation.
 $queued=& $dispatch $PSScriptRoot 'Patch' (Join-Path $scratch 'missing-preparation') $install
 Assert ($queued.State.Installation -eq $install -and $queued.Outcome -eq 'OperationFailed') 'Queued UI action switched to the newer installation'
 $scan=Get-ArchiveInspection $target ('f'*64)
 Assert ($scan.State -eq 'Unreadable') 'Inspection ignored an archive hash change'
 Set-BlockerArchive $target $exe $prep Apply | Out-Null
 $s=Get-DesktopState $prep $install
 Assert ($s.CanRestore -and $s.AppliedMetadataMatches -and !$s.CanPatch) 'Real patched state was not verified'
 Remove-Item -LiteralPath (Join-Path $prep 'blocked.asar')
 $s=Get-DesktopState $prep $install
 Assert ($s.CanRestore -and !$s.PatchValid) 'Missing prepared patch blocked Restore'
 [IO.File]::WriteAllText((Join-Path $prep 'original.asar'),'damaged backup')
 $s=Get-DesktopState $prep $install
 Assert (!$s.CanRestore -and !$s.BackupValid) 'Corrupt original enabled Restore in real discovery'
 [IO.File]::WriteAllText($target,'vendor update')
 $s=Get-DesktopState $prep $install
 Assert (!$s.CanPatch -and !$s.CanRestore -and $s.State -eq 'Unknown archive') 'Vendor update enabled mutation'
 Assert ($s.NodeReady -and $s.Message -match 'layout unsupported' -and $s.Message -notmatch 'Install Node.js') 'Unreadable archive misdiagnosed a working Node runtime'
}finally{
 $env:ProgramFiles=$originalProgramFiles
 Remove-Item Function:\Get-Command,Function:\Get-Process,Function:\Get-Service
 $resolved=[IO.Path]::GetFullPath($scratch)
 $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
 if(!$resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notlike 'blocker-desktop-tests-*'){throw 'Unsafe scratch cleanup path'}
 if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}

# Test the real orchestration with deterministic process/status boundaries; never elevate.
function New-State([string]$State,[bool]$CanPatch,[bool]$CanRestore,[bool]$Marker){
 [pscustomobject]@{ToolVersion='0.2.0';State=$State;Installation="C:\private-user\App Engine";PreparationDirectory="C:\private-user\original's backup";CanPatch=$CanPatch;CanRestore=$CanRestore;CanPrepare=$false;MarkerPresent=$Marker;AppliedMetadataMatches=$Marker;BackupValid=$true;PatchValid=$true;NodeReady=$true;NodeVersion='v22.0.0';ControllersStopped=$true;ArchiveSha256=('a'*64);ExecutableSha256=('b'*64);Message='private exception text'}
}
$original=New-State 'Original' $true $false $false
$patched=New-State 'Experimental blocker applied' $false $true $true
$script:snapshots=@();$script:reads=0;$script:starts=0;$script:exitCode=0;$script:cancel=$false
function Get-DesktopState {
 param($PreparationDirectory,$InstallDirectory)
 $value=$script:snapshots[[Math]::Min($script:reads,$script:snapshots.Count-1)]
 $script:reads++;return $value
}
function Start-Process {
 param($FilePath,$ArgumentList,$Verb,$WindowStyle,[switch]$Wait,[switch]$PassThru)
 $script:starts++
 Assert ($Verb -eq 'RunAs' -and $WindowStyle -eq 'Hidden' -and $Wait -and $PassThru) 'Unexpected elevation configuration'
 Assert ($FilePath -eq (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')) 'Unexpected executable'
 Assert ($ArgumentList -match ' -File "[^"\r\n]+BladeBlocker.Elevated.ps1" -Mode (Apply|Restore) -InstallDirectory ') 'Not a fixed operation helper'
 Assert ($ArgumentList -notmatch '-Command|-EncodedCommand') 'Generic command execution introduced'
 if($script:cancel){throw [ComponentModel.Win32Exception]::new(1223)}
 [pscustomobject]@{ExitCode=$script:exitCode}
}
function Run-Case($Before,$After,[string]$Action,[int]$ExitCode=0,[bool]$Cancel=$false){
 $script:snapshots=@($Before,$After);$script:reads=0;$script:starts=0;$script:exitCode=$ExitCode;$script:cancel=$Cancel
 Invoke-DesktopTask $Action '' ''
}
$r=Run-Case $original $patched Patch
Assert ($r.Outcome -eq 'VerifiedPatch' -and $script:starts -eq 1 -and $script:reads -eq 2) 'Patch success not freshly verified'
$r=Run-Case $patched $original Restore
Assert ($r.Outcome -eq 'VerifiedRestore') 'Restore verification failed'
$r=Run-Case $original $original Patch
Assert ($r.Outcome -eq 'VerificationRequired') 'Exit zero without patched readback claimed success'
Assert ($r.Notice.Contains('app.asar.blade-blocker-backup-*') -and $r.Notice.Contains((Join-Path $original.Installation 'resources'))) 'Failed verification omitted local backup recovery location'
$r=Run-Case $patched $patched Restore
Assert ($r.Outcome -eq 'VerificationRequired') 'Restore with marker remaining claimed success'
$r=Run-Case $original $patched Patch 1
Assert ($r.Outcome -eq 'VerificationRequired') 'Failed helper exit claimed success'
$r=Run-Case $original $original Patch 0 $true
Assert ($r.Outcome -eq 'ElevationCancelled') 'UAC cancellation was not distinguished'
$blocked=New-State 'Original' $false $false $false
$r=Run-Case $blocked $blocked Patch
Assert ($r.Outcome -eq 'OperationFailed' -and $script:starts -eq 0) 'Stale permitted UI state bypassed fresh preflight'
$r=Run-Case $patched $patched Refresh
Assert ($r.Outcome -eq 'Inspection' -and $script:starts -eq 0) 'Refresh attempted elevation'
$report=ConvertTo-DesktopDiagnostic $original 'OperationFailed'
Assert ($report -notmatch 'private-user|original.s backup|private exception|Installation|PreparationDirectory|Message') 'Diagnostic leaked private paths or exceptions'
Assert (($report | ConvertFrom-Json).ArchiveSha256 -eq ('a'*64)) 'Diagnostic omitted archive evidence'
# Cross the real Windows -File argument boundary, without elevation or installed writes.
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('blocker-desktop-boundary-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
try{
 $probe=Join-Path $scratch 'argument probe.ps1';$resultFile=Join-Path $scratch 'arguments.json'
 $probeSource='param([string]$InstallDirectory,[string]$PreparationDirectory,[string]$OutputFile); [IO.File]::WriteAllText($OutputFile,(@{Install=$InstallDirectory;Preparation=$PreparationDirectory}|ConvertTo-Json))'
 [IO.File]::WriteAllText($probe,$probeSource)
 $installArgument="C:\space path\owner's app\";$preparationArgument="C:\backup folder\owner's original"
 $hostPath=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(ConvertTo-DesktopArgument $probe),'-InstallDirectory',(ConvertTo-DesktopArgument $installArgument),'-PreparationDirectory',(ConvertTo-DesktopArgument $preparationArgument),'-OutputFile',(ConvertTo-DesktopArgument $resultFile)) -join ' '
 $p=Microsoft.PowerShell.Management\Start-Process -FilePath $hostPath -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
 Assert ($p.ExitCode -eq 0) 'Native argument probe failed'
 $bound=Get-Content -LiteralPath $resultFile -Raw | ConvertFrom-Json
 Assert ($bound.Install -ceq $installArgument -and $bound.Preparation -ceq $preparationArgument) 'Native argument binding changed selected paths'

 # Exercise the fixed helper contract using an inert local implementation.
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'BladeBlocker.Elevated.ps1') -Destination $scratch
 [IO.File]::WriteAllText((Join-Path $scratch 'BladeBlocker.ps1'),'[CmdletBinding(SupportsShouldProcess=$true)]param([string]$Mode,[string]$InstallDirectory,[string]$PreparationDirectory); if($InstallDirectory -ne "fixture" -or $PreparationDirectory -ne "backup" -or $Mode -notin @("Apply","Restore")){throw "fixture failure"}')
 foreach($mode in @('Apply','Restore','Invalid')){
  $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(ConvertTo-DesktopArgument (Join-Path $scratch 'BladeBlocker.Elevated.ps1')),'-Mode',$mode,'-InstallDirectory','fixture','-PreparationDirectory','backup') -join ' '
  $p=Microsoft.PowerShell.Management\Start-Process -FilePath $hostPath -ArgumentList $args -WindowStyle Hidden -Wait -PassThru
  Assert (($mode -eq 'Invalid' -and $p.ExitCode -ne 0) -or ($mode -ne 'Invalid' -and $p.ExitCode -eq 0)) 'Fixed helper parameter/exit contract failed'
 }
 $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(ConvertTo-DesktopArgument (Join-Path $scratch 'BladeBlocker.Elevated.ps1')),'-Mode','Apply','-InstallDirectory','invalid','-PreparationDirectory','backup') -join ' '
 $p=Microsoft.PowerShell.Management\Start-Process -FilePath $hostPath -ArgumentList $args -WindowStyle Hidden -Wait -PassThru
 Assert ($p.ExitCode -ne 0) 'Fixed helper swallowed operation failure'

 # Exercise preparation orchestration with inert Prepare.ps1 output, including progress noise.
 foreach($file in @('BladeBlocker.Desktop.ps1','Blocker.Common.ps1','package.json')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $scratch}
 [IO.File]::WriteAllText((Join-Path $scratch 'Prepare.ps1'),'param([string]$InstallDirectory); if($InstallDirectory -eq "fail"){throw "fixture preparation failure"}; "progress"; [pscustomobject]@{Prepared=$true;PreparationDirectory="fixture-prepared"}')
 $mockStateBody=${function:Get-DesktopState}
 . (Join-Path $scratch 'BladeBlocker.Desktop.ps1')
 Set-Item Function:\Get-DesktopState $mockStateBody
 $unprepared=New-State 'No matching preparation' $true $false $false;$unprepared.CanPrepare=$true
 $script:snapshots=@($unprepared,$original,$patched);$script:reads=0;$script:starts=0;$script:exitCode=0;$script:cancel=$false
 $r=Invoke-DesktopTask Patch '' ''
 Assert ($r.Outcome -eq 'VerifiedPatch' -and $script:reads -eq 3 -and $script:starts -eq 1) 'Automatic preparation did not recheck before elevating'
 $script:snapshots=@($unprepared,$blocked,$blocked);$script:reads=0;$script:starts=0
 $r=Invoke-DesktopTask Patch '' ''
 Assert ($r.Outcome -eq 'OperationFailed' -and $script:starts -eq 0) 'Changed post-preparation state elevated'
 $unprepared.Installation='fail'
 $r=Run-Case $unprepared $unprepared Patch
 Assert ($r.Outcome -eq 'OperationFailed' -and $script:starts -eq 0) 'Preparation failure elevated'
 $noMetadata=New-State 'Experimental blocker applied' $false $true $true;$noMetadata.AppliedMetadataMatches=$false
 $r=Run-Case $original $noMetadata Patch
 Assert ($r.Outcome -eq 'VerificationRequired') 'Missing metadata claimed Patch success'
 $noBackup=New-State 'Original' $true $false $false;$noBackup.BackupValid=$false
 $r=Run-Case $patched $noBackup Restore
 Assert ($r.Outcome -eq 'VerificationRequired') 'Missing original claimed Restore success'
}finally{
 $resolved=[IO.Path]::GetFullPath($scratch)
 $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
 if(!$resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notlike 'blocker-desktop-boundary-*'){throw 'Unsafe scratch cleanup path'}
 if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
Write-Output "Passed desktop regression checks in PowerShell $($PSVersionTable.PSVersion): state admission, argument quoting, fresh preflight/readback, fixed elevation boundary, cancellation and diagnostic privacy."
