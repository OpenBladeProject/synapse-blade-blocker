[CmdletBinding(SupportsShouldProcess=$true)]
param([ValidateSet('Status','Apply','Restore')][string]$Mode='Status')
$ErrorActionPreference='Stop'
$target='C:\Program Files\Razer\RazerAppEngine\app-4.0.821\resources\app.asar'
$exe='C:\Program Files\Razer\RazerAppEngine\app-4.0.821\RazerAppEngine.exe'
$original='D465C0F2A9AA031160D6BAD01F0F8CB0FC9F623FA2DB7DA3A6D89CC92E4CA775'
$blocked='3FA3CD488659D6C36CD8B8DA580CF57F5873F5BB1769A3CB016DF667B54CFE5F'
$exeHash='B61D8ED657D043FA907AE536C8A7BB345AA8037B23D6603D488F9B5CBCF2B9DA'
function Read-Hash([string]$Path){
 if(![IO.File]::Exists($Path)){return $null}
 $stream=[IO.File]::OpenRead($Path);$sha=[Security.Cryptography.SHA256]::Create()
 try {return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}
 finally {$sha.Dispose();$stream.Dispose()}
}
$current=Read-Hash $target
$actualExe=Read-Hash $exe
$state=if($actualExe -ne $exeHash){'Unsupported installation'}elseif($current -eq $original){'Original'}elseif($current -eq $blocked){'Experimental blocker applied'}else{'Unknown archive'}
if($Mode -eq 'Status'){
 [pscustomobject]@{State=$state;Version='4.0.821';ArchiveSha256=$current;ExecutableMatches=($actualExe -eq $exeHash);OpenBladeConflictBypass=$false;IsolationValidated=$false;ProClickV2UserReportedPass=$true}
 return
}
if($actualExe -ne $exeHash){throw 'Executable differs from the supported build. No files changed; do not apply or restore across an update.'}
if($current -notin @($original,$blocked)){throw 'Unknown installed archive. No files changed; preserve it and reconcile manually.'}
$wanted=if($Mode -eq 'Apply'){$blocked}else{$original}
if($current -eq $wanted){Write-Output "$Mode already satisfied; no files changed.";return}
$source=Join-Path $PSScriptRoot $(if($Mode -eq 'Apply'){'blocked.asar'}else{'original.asar'})
if((Read-Hash $source) -ne $wanted){throw 'Source archive integrity mismatch. No files changed.'}
# Both payloads must be available before applying; restoring does not depend on the patch file.
if($Mode -eq 'Apply' -and (Read-Hash (Join-Path $PSScriptRoot 'original.asar')) -ne $original){throw 'Verified original archive is required before Apply.'}
if(!$PSCmdlet.ShouldProcess($target,"$Mode exact experimental Synapse archive")){return}
if(!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Run Apply/Restore from an administrator PowerShell window. Status does not need elevation.'}
if(Get-Process RazerAppEngine,OpenBlade.Service,OpenBlade.Tray,OpenBlade.SessionAgent -ErrorAction SilentlyContinue){throw 'Exit Synapse and use OpenBlade Settings > Shut down OpenBlade first. This tool stops no processes.'}
$svc=Get-Service OpenBlade -ErrorAction SilentlyContinue
if($svc -and $svc.Status -ne 'Stopped'){throw 'OpenBlade service must be stopped.'}
$stage=$target+'.blade-blocker-stage-'+[guid]::NewGuid().ToString('N')
$backup=$target+'.blade-blocker-backup-'+[guid]::NewGuid().ToString('N')
Copy-Item -LiteralPath $source -Destination $stage
if((Read-Hash $stage) -ne $wanted){throw 'Staged archive mismatch; installed archive unchanged.'}
# Recheck immediately before replacement; do not overwrite a known concurrent update.
if((Read-Hash $target) -ne $current -or (Read-Hash $exe) -ne $exeHash){throw 'Installation changed during preflight; refusing replacement.'}
[IO.File]::Replace($stage,$target,$backup)
if((Read-Hash $target) -ne $wanted -or (Read-Hash $backup) -ne $current -or (Read-Hash $exe) -ne $exeHash){throw "Replacement verification failed. Do not launch Synapse. Preserved backup: $backup"}
[pscustomobject]@{Mode=$Mode;Success=$true;ArchiveSha256=$wanted;Backup=$backup;OpenBladeConflictBypass=$false}



