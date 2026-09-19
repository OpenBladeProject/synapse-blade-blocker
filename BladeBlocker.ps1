[CmdletBinding(SupportsShouldProcess=$true)]
param([ValidateSet('Status','Apply','Restore')][string]$Mode='Status',[string]$InstallDirectory,[string]$PreparationDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Blocker.Common.ps1')
try {
$env:BLOCKER_POWERSHELL_VERSION=$PSVersionTable.PSVersion.ToString()
$install=Resolve-AppEngine $InstallDirectory
$target=Join-Path $install 'resources\app.asar'
$exe=Join-Path $install 'RazerAppEngine.exe'
$current=Read-Hash $target
$actualExe=Read-Hash $exe
try{$directory=Find-Preparation $PreparationDirectory $current $actualExe;$m=Read-Preparation $directory}catch{if($Mode -ne 'Status'){throw};$m=$null}
$state=if(!$m -or $actualExe -ne $m.executableSha256){'No matching preparation'}elseif($current -eq $m.originalAsarSha256){'Original'}elseif($current -eq $m.patchedAsarSha256){'Experimental blocker applied'}else{'Unknown archive'}
if($Mode -eq 'Status'){
 $marker=Join-Path $install 'resources\synapse-blade-blocker.json'
 [pscustomobject]@{State=$state;Installation=$install;ArchiveSha256=$current;ExecutableSha256=$actualExe;AppliedMetadataMatches=($m -and $current -eq $m.patchedAsarSha256 -and (Test-AppliedMarker $marker $m));IsolationValidated=$false}
 return
}
if(!$m -or $actualExe -ne $m.executableSha256 -or $current -notin @($m.originalAsarSha256,$m.patchedAsarSha256)){throw 'Installation does not match this preparation. Preserve unknown updates; prepare the new original build.'}
$wanted=if($Mode -eq 'Apply'){$m.patchedAsarSha256}else{$m.originalAsarSha256}
$source=Join-Path $directory $(if($Mode -eq 'Apply'){'blocked.asar'}else{'original.asar'})
if((Read-Hash $source) -ne $wanted -or (Read-Hash (Join-Path $directory 'original.asar')) -ne $m.originalAsarSha256){throw 'Source/rollback archive integrity mismatch; no files changed.'}
if(!$PSCmdlet.ShouldProcess($target,"$Mode locally prepared Synapse archive and applied metadata")){return}
if(!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Run Apply/Restore from an administrator PowerShell window. Status does not need elevation.'}
if(Get-Process RazerAppEngine,OpenBlade.Service,OpenBlade.Tray,OpenBlade.SessionAgent -ErrorAction SilentlyContinue){throw 'Exit Synapse and use OpenBlade Settings > Shut down OpenBlade first. This tool stops no processes.'}
$svc=Get-Service OpenBlade -ErrorAction SilentlyContinue
if($svc -and $svc.Status -ne 'Stopped'){throw 'OpenBlade service must be stopped.'}
Set-BlockerArchive $target $exe $directory $Mode

}catch{
 try { & node (Join-Path $PSScriptRoot 'failure-report.cjs') $Mode $_.Exception.Message $target $exe $PSVersionTable.PSVersion.ToString() } catch { Write-Warning 'Diagnostic reporting failed; the original error follows.' }
 throw
}
