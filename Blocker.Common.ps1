$ErrorActionPreference='Stop'
function Invoke-BlockerNode([string[]]$Arguments,[switch]$DiscardStandardError) {
 $node=Get-Command node -CommandType Application -ErrorAction Stop | Select-Object -First 1
 if(!$node){throw 'Node.js is unavailable.'}
 $previousPreference=$ErrorActionPreference
 try {
  # WinPS 5.1 hostless runspaces convert native stderr to ErrorRecords. A
  # diagnostic is not an exit failure; decide from the captured native code.
  $ErrorActionPreference='Continue'
  if($DiscardStandardError){$output=@(& $node.Source @Arguments 2>$null)}
  else{$output=@(& $node.Source @Arguments)}
  $exitCode=$LASTEXITCODE
 }finally{$ErrorActionPreference=$previousPreference}
 [pscustomobject]@{Output=$output;ExitCode=$exitCode}
}
function Get-ToolVersion {
 $package=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'package.json') -Raw | ConvertFrom-Json
 $version=[string]$package.version
 if($version -cnotmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$'){throw 'package.json contains an invalid tool version.'}
 return $version
}
function Read-Hash([string]$Path){
 if(![IO.File]::Exists($Path)){return $null}
 $stream=[IO.File]::OpenRead($Path);$sha=[Security.Cryptography.SHA256]::Create()
 try{return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant()}
 finally{$sha.Dispose();$stream.Dispose()}
}
function Resolve-FileSystemPath([string]$Path){
 $provider=$null;$drive=$null
 $full=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path,[ref]$provider,[ref]$drive)
 if($provider.Name -ne 'FileSystem'){throw 'Expected a filesystem path.'}
 return $full
}
function Resolve-AppEngine([string]$InstallDirectory){
 $root=[IO.Path]::GetFullPath((Join-Path $env:ProgramFiles 'Razer\RazerAppEngine'))
 function Check-Directory([string]$Directory){
  $full=(Resolve-FileSystemPath $Directory).TrimEnd('\')
  if([IO.Path]::GetDirectoryName($full) -ne $root -or [IO.Path]::GetFileName($full) -notmatch '^app-\d+(\.\d+){1,3}$'){throw 'Expected a standard Program Files\Razer\RazerAppEngine\app-VERSION directory.'}
  foreach($p in @($root,$full,(Join-Path $full 'resources'),(Join-Path $full 'RazerAppEngine.exe'),(Join-Path $full 'resources\app.asar'))){
   $item=Get-Item -LiteralPath $p -Force
   if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse-point installation paths are not supported.'}
  }
  return $full
 }
 if($InstallDirectory){return Check-Directory $InstallDirectory}
 $running=@(Get-Process RazerAppEngine -ErrorAction SilentlyContinue)
 if($running.Count){
  $paths=@($running | ForEach-Object {if(!$_.Path){throw 'Cannot resolve active AppEngine path. Close Synapse or specify its standard installation directory.'};[IO.Path]::GetDirectoryName($_.Path)} | Select-Object -Unique)
  if($paths.Count -ne 1){throw 'Multiple AppEngine installations are running; close Synapse before selecting an installation.'}
  return Check-Directory $paths[0]
 }
 $candidates=@(Get-ChildItem -LiteralPath $root -Directory | Where-Object {$_.Name -match '^app-\d+(\.\d+){1,3}$'} | Sort-Object {[version]$_.Name.Substring(4)} -Descending)
 if(!$candidates.Count){throw 'No standard Razer AppEngine installation was found.'}
 return Check-Directory $candidates[0].FullName
}
function Read-Preparation([string]$Directory){
 $m=Get-Content -LiteralPath (Join-Path $Directory 'preparation.json') -Raw | ConvertFrom-Json
 if($m.schemaVersion -ne 1 -or $m.patchId -cne 'OSSBlade/synapse-blade-blocker'){throw 'Invalid preparation identity.'}
 foreach($hash in @($m.originalAsarSha256,$m.patchedAsarSha256,$m.executableSha256)){if($hash -cnotmatch '^[a-f0-9]{64}$'){throw 'Invalid preparation hash.'}}
 if($m.originalAsarSha256 -eq $m.patchedAsarSha256){throw 'Preparation did not change the archive.'}
 if(!@($m.bladeProductIds).Count){throw 'Preparation has no Blade IDs.'}
 foreach($pidValue in $m.bladeProductIds){if($pidValue -isnot [int] -and $pidValue -isnot [long]){throw 'Blade IDs must be numeric.'};if($pidValue -lt 1 -or $pidValue -gt 65535){throw 'Invalid Blade ID.'}}
 return $m
}
function Get-BackupSettingsPath {
 if([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA) -or $env:LOCALAPPDATA -notmatch '^(?:[A-Za-z]:[\\/]|\\\\)'){throw 'The current user Local AppData folder is unavailable.'}
 return Join-Path $env:LOCALAPPDATA 'SynapseBladeBlocker\settings.json'
}
function Resolve-BackupDirectory($Directory) {
 if($Directory -isnot [string] -or $Directory -notmatch '^(?:[A-Za-z]:[\\/]|\\\\)'){throw 'Choose an absolute backup folder path.'}
 $full=[IO.Path]::GetFullPath($Directory)
 if($full.Length -gt [IO.Path]::GetPathRoot($full).Length){return $full.TrimEnd('\','/')}
 return $full
}
function Get-UniqueBackupDirectories([object[]]$Directories) {
 $known=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
 foreach($directory in $Directories){
  try{$resolved=Resolve-BackupDirectory $directory}catch{continue}
  if($known.Add($resolved)){$resolved}
 }
}
function Get-DefaultBackupRoot {
 $documents=[Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
 return Join-Path (Resolve-BackupDirectory $documents) 'Synapse Blade Blocker\Backups'
}
function Read-BackupSettings {
 $path=Get-BackupSettingsPath
 if(!(Test-Path -LiteralPath $path)){return $null}
 if((Get-Item -LiteralPath $path).Length -gt 65536){throw 'Backup location settings are too large.'}
 $settings=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
 if($settings.schemaVersion -ne 1){throw 'Unsupported backup location settings.'}
 try{$directory=Resolve-BackupDirectory $settings.backupDirectory}catch{$directory=$null}
 $previous=@(Get-UniqueBackupDirectories @($settings.previousBackupDirectories))
 return [pscustomobject]@{schemaVersion=1;backupDirectory=$directory;previousBackupDirectories=$previous}
}
function Get-BackupRoot {
 $settings=Read-BackupSettings
 if($settings){if(!$settings.backupDirectory){throw 'The saved backup location is invalid.'};return $settings.backupDirectory}
 return Get-DefaultBackupRoot
}
function Set-BackupRoot([string]$Directory) {
 $directory=Resolve-BackupDirectory $Directory
 $path=Get-BackupSettingsPath
 try{$previous=Read-BackupSettings}catch{$previous=$null}
 $older=@()
 if($previous){$older=@($previous.backupDirectory)+@($previous.previousBackupDirectories)}
 $older=@(Get-UniqueBackupDirectories $older | Where-Object {$_ -ne $directory})
 Assert-BackupLocationWritable $directory
 [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
 $settings=[ordered]@{schemaVersion=1;backupDirectory=$directory;previousBackupDirectories=$older}
 $stage=$path+'.stage-'+[guid]::NewGuid().ToString('N')
 [IO.File]::WriteAllText($stage,($settings | ConvertTo-Json -Depth 3),(New-Object Text.UTF8Encoding $false))
 if(Test-Path -LiteralPath $path){[IO.File]::Replace($stage,$path,$path+'.previous')}else{[IO.File]::Move($stage,$path)}
 if((Get-BackupRoot) -ne $directory){throw 'Backup location settings could not be verified.'}
}
function Get-BackupSearchRoots {
 $roots=@()
 try{$settings=Read-BackupSettings;if($settings){if($settings.backupDirectory){$roots+=$settings.backupDirectory};$roots+=@($settings.previousBackupDirectories)}}catch{}
 try{$roots+=Get-DefaultBackupRoot}catch{}
 if($env:LOCALAPPDATA -match '^(?:[A-Za-z]:[\\/]|\\\\)'){$roots+=Join-Path $env:LOCALAPPDATA 'SynapseBladeBlocker\Backups'}
 $roots+=Join-Path $PSScriptRoot 'prepared'
 return @(Get-UniqueBackupDirectories $roots)
}
function Test-PreparedPatch([string]$Directory) {
 try{
  $process=Invoke-BlockerNode -Arguments @((Join-Path $PSScriptRoot 'preparation-identity.cjs'),'--verify-preparation',$Directory) -DiscardStandardError
  return $process.ExitCode -eq 0 -and ($process.Output -join '').Trim() -ceq 'true'
 }catch{return $false}
}
function Assert-BackupLocationWritable([string]$Directory) {
 $probe=Join-Path $Directory ('.write-check-'+[guid]::NewGuid().ToString('N'))
 try{
  [void][IO.Directory]::CreateDirectory($Directory)
  $stream=[IO.File]::Open($probe,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try{$stream.WriteByte(0)}finally{$stream.Dispose()}
  Remove-Item -LiteralPath $probe -ErrorAction Stop
 }catch{throw 'Backup location is unavailable or not writable. Choose another backup location.'}
}
function Find-Preparation([string]$Directory,[string]$ArchiveHash,[string]$ExecutableHash){
 if($Directory){return Resolve-FileSystemPath $Directory}
 $roots=Get-BackupSearchRoots
 $matching=$null
 foreach($root in $roots){
  if(Test-Path -LiteralPath $root -PathType Container){
   try{$candidates=@(Get-ChildItem -LiteralPath $root -Directory -ErrorAction Stop | Sort-Object Name -Descending)}catch{continue}
   foreach($candidate in $candidates){
    try{
     $m=Read-Preparation $candidate.FullName
     if($m.executableSha256 -eq $ExecutableHash -and $ArchiveHash -in @($m.originalAsarSha256,$m.patchedAsarSha256)){
      if(!$matching){$matching=$candidate.FullName}
      if((Read-Hash (Join-Path $candidate.FullName 'original.asar')) -eq $m.originalAsarSha256){return $candidate.FullName}
     }
    }catch{continue}
   }
  }
 }
 # Retain a matching but damaged candidate so the desktop can explain its missing backup.
 if($matching){return $matching}
 throw 'No matching local preparation. Check the backups folder or choose an older preparation; preserve all backups.'
}
function Read-UtcTimestamp($Value){
 # PowerShell 7 may deserialize JSON timestamps as DateTime; PowerShell 5 leaves strings.
 if($Value -is [DateTime]){
  if($Value.Kind -eq [DateTimeKind]::Unspecified){throw 'Applied timestamp requires a timezone.'}
  return [DateTimeOffset]::new($Value.ToUniversalTime())
 }
 $stamp=[DateTimeOffset]::Parse([string]$Value,[Globalization.CultureInfo]::InvariantCulture)
 if($stamp.Offset -ne [TimeSpan]::Zero -or [string]$Value -notmatch '(Z|[+]00:00)$'){throw 'Applied timestamp must be UTC.'}
 return $stamp.ToUniversalTime()
}
function Write-AppliedMarker([string]$Marker,$Metadata){
 $record=[ordered]@{schemaVersion=1;patchId='OSSBlade/synapse-blade-blocker';archiveSha256=$Metadata.patchedAsarSha256;executableSha256=$Metadata.executableSha256;appliedAtUtc=[DateTime]::UtcNow.ToString('o');bladeProductIds=@($Metadata.bladeProductIds)}
 $stage=$Marker+'.stage-'+[guid]::NewGuid().ToString('N')
 [IO.File]::WriteAllText($stage,($record | ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding $false))
 if(Test-Path -LiteralPath $Marker){[IO.File]::Replace($stage,$Marker,$Marker+'.backup-'+[guid]::NewGuid().ToString('N'))}else{[IO.File]::Move($stage,$Marker)}
 $read=Get-Content -LiteralPath $Marker -Raw | ConvertFrom-Json
 if($read.archiveSha256 -ne $record.archiveSha256 -or $read.executableSha256 -ne $record.executableSha256 -or (Read-UtcTimestamp $read.appliedAtUtc) -ne (Read-UtcTimestamp $record.appliedAtUtc)){throw 'Applied metadata verification failed; do not start Synapse.'}
}
function Test-AppliedMarker([string]$Marker,$Metadata){
 try{
  $m=Get-Content -LiteralPath $Marker -Raw | ConvertFrom-Json
  $stamp=Read-UtcTimestamp $m.appliedAtUtc
  return $m.schemaVersion -eq 1 -and $m.patchId -ceq 'OSSBlade/synapse-blade-blocker' -and $m.archiveSha256 -eq $Metadata.patchedAsarSha256 -and $m.executableSha256 -eq $Metadata.executableSha256 -and $stamp -le [DateTimeOffset]::UtcNow -and (($m.bladeProductIds | Sort-Object -Unique) -join ',') -eq (($Metadata.bladeProductIds | Sort-Object -Unique) -join ',')
 }catch{return $false}
}
function Set-BlockerArchive([string]$Target,[string]$Executable,[string]$Directory,[string]$Mode){
 $m=Read-Preparation $Directory
 $current=Read-Hash $Target
 if((Read-Hash $Executable) -ne $m.executableSha256 -or $current -notin @($m.originalAsarSha256,$m.patchedAsarSha256)){throw 'Installation changed or is unknown. Preserve it; no replacement performed.'}
 $wanted=if($Mode -eq 'Apply'){$m.patchedAsarSha256}else{$m.originalAsarSha256}
 $source=Join-Path $Directory $(if($Mode -eq 'Apply'){'blocked.asar'}else{'original.asar'})
 if((Read-Hash $source) -ne $wanted){throw 'Source archive integrity mismatch.'}
 if((Read-Hash (Join-Path $Directory 'original.asar')) -ne $m.originalAsarSha256){throw 'Verified original backup is required.'}
 $marker=Join-Path ([IO.Path]::GetDirectoryName($Target)) 'synapse-blade-blocker.json'
 $backup=$null
 if($current -ne $wanted){
  $stage=$Target+'.blade-blocker-stage-'+[guid]::NewGuid().ToString('N')
  $backup=$Target+'.blade-blocker-backup-'+[guid]::NewGuid().ToString('N')
  Copy-Item -LiteralPath $source -Destination $stage
  if((Read-Hash $stage) -ne $wanted){throw 'Staged archive mismatch; installation unchanged.'}
  if((Read-Hash $Target) -ne $current -or (Read-Hash $Executable) -ne $m.executableSha256){throw 'Installation changed during preflight; refusing replacement.'}
  [IO.File]::Replace($stage,$Target,$backup)
  if((Read-Hash $backup) -ne $current){throw "Replacement backup verification failed; preserve $backup"}
 }
 if((Read-Hash $Target) -ne $wanted -or (Read-Hash $Executable) -ne $m.executableSha256){throw "Replacement verification failed; preserve backup $backup and do not launch Synapse."}
 if($Mode -eq 'Apply'){
  if(!(Test-AppliedMarker $marker $m)){Write-AppliedMarker $marker $m}
 }elseif(Test-Path -LiteralPath $marker){Remove-Item -LiteralPath $marker}
 [pscustomobject]@{ToolVersion=(Get-ToolVersion);Mode=$Mode;Success=$true;ArchiveSha256=$wanted;Backup=$backup;PreparationDirectory=$Directory;AppliedMetadata=($Mode -eq 'Apply')}
}

# Content inspection is independent evidence, never backup or write authorization.
function Get-ArchiveInspection([string]$Archive,[string]$ExpectedHash) {
 $unavailable=[pscustomobject]@{State='Unreadable';ArchiveSha256=$null;Evidence=@()}
 try {
  $process=Invoke-BlockerNode -Arguments @((Join-Path $PSScriptRoot 'inspect-archive.cjs'),$Archive) -DiscardStandardError
  if($process.ExitCode -ne 0){return $unavailable}
  $inspection=($process.Output -join [Environment]::NewLine) | ConvertFrom-Json
  if($inspection.State -notin @('CurrentPatch','LegacyPatch','PartialPatch','NoPatchDetected','Unreadable') -or $inspection.ArchiveSha256 -cne $ExpectedHash){return $unavailable}
  return $inspection
 }catch{return $unavailable}
}
