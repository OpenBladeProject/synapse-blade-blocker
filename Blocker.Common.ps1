$ErrorActionPreference='Stop'
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
function Find-Preparation([string]$Directory,[string]$ArchiveHash,[string]$ExecutableHash){
 if($Directory){return Resolve-FileSystemPath $Directory}
 $root=Join-Path $PSScriptRoot 'prepared'
 if(Test-Path -LiteralPath $root){
  foreach($candidate in (Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending)){
   try{$m=Read-Preparation $candidate.FullName}catch{continue}
   if($m.executableSha256 -eq $ExecutableHash -and $ArchiveHash -in @($m.originalAsarSha256,$m.patchedAsarSha256)){return $candidate.FullName}
  }
 }
 throw 'No matching local preparation. Run Prepare.ps1 for this installation; preserve all older preparations.'
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
  $node=Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if(!$node){return $unavailable}
  $json=& $node.Source (Join-Path $PSScriptRoot 'inspect-archive.cjs') $Archive 2>$null
  if($LASTEXITCODE -ne 0){return $unavailable}
  $inspection=($json -join [Environment]::NewLine) | ConvertFrom-Json
  if($inspection.State -notin @('CurrentPatch','LegacyPatch','PartialPatch','NoPatchDetected','Unreadable') -or $inspection.ArchiveSha256 -cne $ExpectedHash){return $unavailable}
  return $inspection
 }catch{return $unavailable}
}
