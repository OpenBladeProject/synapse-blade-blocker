# Shared desktop orchestration. Installed-file operations remain in BladeBlocker.ps1.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Blocker.Common.ps1')

function ConvertTo-DesktopArgument([string]$Value) {
 if($Value -match '["\r\n\x00]'){throw 'Unsupported character in operation argument.'}
 # CommandLineToArgvW requires trailing backslashes to be doubled before a quote.
 return '"'+[regex]::Replace($Value,'(\\+)$','$1$1')+'"'
}

function Get-DesktopActions([string]$State,[bool]$MarkerPresent,[bool]$BackupValid,[bool]$PatchValid,[bool]$NodeReady,[bool]$ControllersStopped,[bool]$ExplicitPreparation) {
 $known=$State -in @('Original','Experimental blocker applied')
 $canPrepare=$State -eq 'No matching preparation' -and !$MarkerPresent -and !$ExplicitPreparation
 [pscustomobject]@{
  CanPatch=($NodeReady -and $ControllersStopped -and (($State -eq 'Original' -and $BackupValid -and $PatchValid) -or $canPrepare))
  CanRestore=($known -and $State -eq 'Experimental blocker applied' -and $BackupValid -and $ControllersStopped)
  CanPrepare=$canPrepare
 }
}

function Get-DesktopState([string]$PreparationDirectory,[string]$InstallDirectory) {
 $result=[ordered]@{ToolVersion=(Get-ToolVersion);State='Unavailable';Installation=$null;PreparationDirectory=$PreparationDirectory;MarkerPresent=$false;BackupValid=$false;PatchValid=$false;NodeReady=$false;NodeVersion='Unavailable';ControllersStopped=$false;ArchiveSha256=$null;ExecutableSha256=$null;AppliedMetadataMatches=$false;CanPatch=$false;CanRestore=$false;CanPrepare=$false;Message=''}
 try{
  $node=Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if($node){$v=[string](& $node.Source --version 2>$null);if($LASTEXITCODE -eq 0 -and $v -match '^v(\d+)\.\d+\.\d+$'){$result.NodeVersion=$v;$result.NodeReady=[int]$Matches[1] -ge 22}}
 }catch{}
 try{
  $install=Resolve-AppEngine $InstallDirectory
  $status=& (Join-Path $PSScriptRoot 'BladeBlocker.ps1') -Mode Status -InstallDirectory $install -PreparationDirectory $PreparationDirectory
  foreach($key in @('State','Installation','ArchiveSha256','ExecutableSha256','AppliedMetadataMatches')){$result[$key]=$status.$key}
  $result.MarkerPresent=Test-Path -LiteralPath (Join-Path $install 'resources\synapse-blade-blocker.json')
  try{
   $directory=Find-Preparation $PreparationDirectory $status.ArchiveSha256 $status.ExecutableSha256
   $m=Read-Preparation $directory
   if($m.executableSha256 -eq $status.ExecutableSha256 -and $status.ArchiveSha256 -in @($m.originalAsarSha256,$m.patchedAsarSha256)){
    $result.PreparationDirectory=$directory
    $result.BackupValid=(Read-Hash (Join-Path $directory 'original.asar')) -eq $m.originalAsarSha256
    $result.PatchValid=(Read-Hash (Join-Path $directory 'blocked.asar')) -eq $m.patchedAsarSha256
   }
  }catch{}
  $processes=@(Get-Process RazerAppEngine,OpenBlade.Service,OpenBlade.Tray,OpenBlade.SessionAgent -ErrorAction SilentlyContinue)
  $svc=Get-Service OpenBlade -ErrorAction SilentlyContinue
  $result.ControllersStopped=$processes.Count -eq 0 -and (!$svc -or $svc.Status -eq 'Stopped')
  $actions=Get-DesktopActions $result.State $result.MarkerPresent $result.BackupValid $result.PatchValid $result.NodeReady $result.ControllersStopped ([bool]$PreparationDirectory)
  foreach($key in @('CanPatch','CanRestore','CanPrepare')){$result[$key]=$actions.$key}
  $notes=New-Object 'System.Collections.Generic.List[string]'
  if($result.State -eq 'No matching preparation' -and $result.MarkerPresent){$notes.Add('Applied metadata exists, but its matching preparation is unavailable. Choose the original preparation folder. Patch and Restore are disabled to protect the current archive.')}
  elseif($result.State -eq 'Unknown archive' -or ($result.State -eq 'No matching preparation' -and $PreparationDirectory)){$notes.Add('This preparation does not match the installed files. Synapse may have updated. Choose a matching preparation or use Automatic to inspect the current installation; keep all older backups.')}
  elseif($result.State -eq 'Experimental blocker applied'){$notes.Add('The archive matches a local patched preparation. Restart Synapse manually after closing this tool, then check OpenBlade.');if(!$result.AppliedMetadataMatches){$notes.Add('Applied metadata is missing or does not match. Restore the verified original before patching again.')}}
  elseif($result.State -eq 'Original'){$notes.Add('The installed archive matches the original in this preparation.')}
  else{$notes.Add('Patch will first prepare and validate this archive locally. Preparation preserves the installed files and creates a new backup folder.')}
  if($result.State -in @('Original','Experimental blocker applied') -and !$result.BackupValid){$notes.Add('The original backup is missing or has changed. Select an intact matching preparation before continuing.')}
  if($result.State -eq 'Original' -and !$result.PatchValid){$notes.Add('The prepared patch is missing or has changed. Preserve this folder and select a valid preparation.')}
  if(!$result.ControllersStopped){$notes.Add('Patch and Restore remain disabled while Synapse or OpenBlade is running. Refresh after closing them.')}
  if(!$result.NodeReady){$notes.Add('Patch requires Node.js 22 or newer on PATH. Install it from nodejs.org and reopen this window. A verified Restore does not require Node.js.')}
  $result.Message=$notes -join "`n`n"
 }catch{$result.Message='Could not inspect a standard AppEngine installation. Install Razer Synapse, close duplicate AppEngine instances, then Refresh. Installed files were not changed.'}
 [pscustomobject]$result
}

function ConvertTo-DesktopDiagnostic($State,[string]$Outcome='Inspection') {
 # Explicit allowlist: never copy installation/preparation paths or raw exceptions.
 $report=[ordered]@{Tool='Synapse Blade Blocker';ToolVersion=$State.ToolVersion;Outcome=$Outcome;State=$State.State;NodeVersion=$State.NodeVersion;NodeReady=[bool]$State.NodeReady;ControllersStopped=[bool]$State.ControllersStopped;MarkerPresent=[bool]$State.MarkerPresent;AppliedMetadataMatches=[bool]$State.AppliedMetadataMatches;OriginalBackupVerified=[bool]$State.BackupValid;PatchedArchiveVerified=[bool]$State.PatchValid;ArchiveSha256=$State.ArchiveSha256;ExecutableSha256=$State.ExecutableSha256;IsolationValidated=$false}
 $report | ConvertTo-Json
}

function Invoke-DesktopTask([ValidateSet('Refresh','Patch','Restore')][string]$Action,[string]$PreparationDirectory,[string]$InstallDirectory) {
 $notice='';$outcome='Inspection'
 $state=Get-DesktopState $PreparationDirectory $InstallDirectory
 if($Action -ne 'Refresh'){
  try{
   if($Action -eq 'Patch'){
    if(!$state.CanPatch){throw 'PreconditionsChanged'}
    if($state.CanPrepare){
     # Prepare emits builder progress as well as its final object; retain only that object.
     $prepared=@(& (Join-Path $PSScriptRoot 'Prepare.ps1') -InstallDirectory $state.Installation) | Where-Object {$_ -isnot [string] -and $_.Prepared -eq $true} | Select-Object -Last 1
     if(!$prepared){throw 'PreparationFailed'}
     $PreparationDirectory=$prepared.PreparationDirectory
     $state=Get-DesktopState $PreparationDirectory $state.Installation
     if(!$state.CanPatch){throw 'PreconditionsChanged'}
    }
   }elseif(!$state.CanRestore){throw 'PreconditionsChanged'}
   $mode=if($Action -eq 'Patch'){'Apply'}else{'Restore'}
   $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(ConvertTo-DesktopArgument (Join-Path $PSScriptRoot 'BladeBlocker.Elevated.ps1')),'-Mode',$mode,'-InstallDirectory',(ConvertTo-DesktopArgument $state.Installation),'-PreparationDirectory',(ConvertTo-DesktopArgument $state.PreparationDirectory)) -join ' '
   $process=Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $args -Verb RunAs -WindowStyle Hidden -Wait -PassThru
   $exitCode=$process.ExitCode
   $state=Get-DesktopState $state.PreparationDirectory $state.Installation
   $verified=if($Action -eq 'Patch'){$state.State -eq 'Experimental blocker applied' -and $state.AppliedMetadataMatches -and $state.BackupValid}else{$state.State -eq 'Original' -and !$state.MarkerPresent -and $state.BackupValid}
   if($exitCode -ne 0 -or !$verified){$outcome='VerificationRequired';$notice='The operation did not complete with verified success. Do not restart Synapse yet. Inspect the status below and keep all preparations and backups.'}
   else{$outcome='Verified'+$Action;$notice=if($Action -eq 'Patch'){'Patch verified on disk. Restart Synapse manually, then check its status in OpenBlade. Keep this package and its prepared folder for Restore.'}else{'Original archive restored and verified; applied metadata removed. You can restart Synapse manually. All backups were preserved.'}}
  }catch{
   $cancelled=$false;$errorException=$_.Exception
   while($errorException){if($errorException -is [ComponentModel.Win32Exception] -and $errorException.NativeErrorCode -eq 1223){$cancelled=$true};$errorException=$errorException.InnerException}
   $outcome=if($cancelled){'ElevationCancelled'}else{'OperationFailed'}
   $notice=if($cancelled){'Administrator approval was cancelled. The elevated operation did not start. Any completed preparation was preserved.'}else{'The operation stopped. Preconditions may have changed or preparation may be incompatible. Refresh, check the requirements below, and keep all backups. Use Open saved reports for structural compatibility details, or Copy diagnostic details to report this status at github.com/OSSBlade/synapse-blade-blocker/issues.'}
   $state=Get-DesktopState $state.PreparationDirectory $state.Installation
  }
 }
 [pscustomobject]@{State=$state;Notice=$notice;Outcome=$outcome}
}
