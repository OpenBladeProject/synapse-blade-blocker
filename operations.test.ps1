$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Blocker.Common.ps1')
function Assert($Condition,[string]$Message){if(!$Condition){throw $Message}}
function Throws([scriptblock]$Action,[string]$Message){$failed=$false;try{& $Action | Out-Null}catch{$failed=$true};Assert $failed $Message}
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('blocker-operations-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
$oldProgramFiles=$env:ProgramFiles
try{
 $env:ProgramFiles=Join-Path $scratch 'ProgramFiles'
 $hostExe=(Microsoft.PowerShell.Management\Get-Process -Id $PID -ErrorAction Stop).Path
 $packageVersion=[string](Get-Content -LiteralPath (Join-Path $PSScriptRoot 'package.json') -Raw | ConvertFrom-Json).version
 $reportedVersion=& $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'BladeBlocker.ps1') -Version
 Assert ($LASTEXITCODE -eq 0 -and [string]$reportedVersion -ceq $packageVersion) 'Offline -Version did not match package.json'
 $engineRoot=Join-Path $env:ProgramFiles 'Razer\RazerAppEngine'
 foreach($version in @('4.0.821','99.1.0')){
  $dir=Join-Path $engineRoot ('app-'+$version)
  New-Item -ItemType Directory -Path (Join-Path $dir 'resources') -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $dir 'RazerAppEngine.exe'),'fixture executable '+$version)
  [IO.File]::WriteAllText((Join-Path $dir 'resources\app.asar'),'original '+$version)
 }
 function Get-Process {param($Name,$ErrorAction) if($script:activePath){[pscustomobject]@{Path=$script:activePath}}}
 $script:activePath=$null
 $install=Join-Path $engineRoot 'app-99.1.0'
 Assert ((Resolve-AppEngine '') -eq $install) 'Newest future installation was not selected'
 $script:activePath=Join-Path $engineRoot 'app-4.0.821\RazerAppEngine.exe'
 Assert ((Resolve-AppEngine '') -eq (Join-Path $engineRoot 'app-4.0.821')) 'Active process path did not win'
 $script:activePath=$null
 Throws {Resolve-AppEngine $scratch} 'Nonstandard explicit directory accepted'
 $target=Join-Path $install 'resources\app.asar'
 $exe=Join-Path $install 'RazerAppEngine.exe'
 $preparation=Join-Path $scratch 'preparation'
 New-Item -ItemType Directory -Path $preparation | Out-Null
 Copy-Item -LiteralPath $target -Destination (Join-Path $preparation 'original.asar')
 [IO.File]::WriteAllText((Join-Path $preparation 'blocked.asar'),'patched future build')
 $meta=[ordered]@{schemaVersion=1;patchId='OSSBlade/synapse-blade-blocker';originalAsarSha256=(Read-Hash $target);patchedAsarSha256=(Read-Hash (Join-Path $preparation 'blocked.asar'));executableSha256=(Read-Hash $exe);bladeProductIds=@(563,736)}
 $meta | ConvertTo-Json | Set-Content (Join-Path $preparation 'preparation.json')
 $status=& (Join-Path $PSScriptRoot 'BladeBlocker.ps1') -Mode Status -InstallDirectory $install -PreparationDirectory $preparation
 Assert ($status.ToolVersion -ceq $packageVersion) 'Status result version did not match package.json'
 # PowerShell location can differ from the process working directory.
 $processDirectory=[Environment]::CurrentDirectory
 Push-Location $scratch
 try{
  Assert ([Environment]::CurrentDirectory -eq $processDirectory) 'Fixture changed process working directory'
  Assert ((Resolve-AppEngine '.\ProgramFiles\Razer\RazerAppEngine\app-99.1.0') -eq $install) 'Relative installation ignored PowerShell location'
  Assert ((Find-Preparation '.\preparation' '' '') -eq $preparation) 'Relative preparation ignored PowerShell location'
  Throws {Resolve-FileSystemPath 'Env:\ProgramFiles'} 'Non-filesystem provider accepted'
 }finally{Pop-Location}
 $result=Set-BlockerArchive $target $exe $preparation Apply
 $marker=Join-Path $install 'resources\synapse-blade-blocker.json'
 Assert $result.Success 'Apply failed'
 Assert ($result.ToolVersion -ceq $packageVersion) 'Apply result version did not match package.json'
 Assert ((Read-Hash $result.Backup) -eq $meta.originalAsarSha256) 'Original atomic backup was not preserved'
 $applied=Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
 Assert (Test-AppliedMarker $marker $meta) 'Applied marker did not verify'
 Assert (($applied.PSObject.Properties.Name | Sort-Object) -join ',' -eq 'appliedAtUtc,archiveSha256,bladeProductIds,executableSha256,patchId,schemaVersion') 'Sidecar fields differ from agreed contract'
 $markerHash=Read-Hash $marker
 $again=Set-BlockerArchive $target $exe $preparation Apply
 Assert (!$again.Backup -and (Read-Hash $marker) -eq $markerHash) 'Reapply was not idempotent'
 $originalMarker=[IO.File]::ReadAllText($marker)
 $stamp=[DateTime]::UtcNow.AddDays(-1)
 Assert ((Read-UtcTimestamp $stamp) -eq (Read-UtcTimestamp $stamp.ToString('o'))) 'UTC DateTime and JSON string differ'
 Assert ((Read-UtcTimestamp $stamp.ToLocalTime()) -eq (Read-UtcTimestamp $stamp)) 'Local DateTime lost its UTC instant'
 $applied.appliedAtUtc=[DateTime]::UtcNow.AddDays(1).ToString('o')
 $applied | ConvertTo-Json | Set-Content -LiteralPath $marker
 Assert (!(Test-AppliedMarker $marker $meta)) 'Future marker accepted'
 $applied.appliedAtUtc='invalid timestamp'
 $applied | ConvertTo-Json | Set-Content -LiteralPath $marker
 Assert (!(Test-AppliedMarker $marker $meta)) 'Malformed marker timestamp accepted'
 [IO.File]::WriteAllText($marker,$originalMarker)
 Remove-Item -LiteralPath $marker
 Set-BlockerArchive $target $exe $preparation Apply | Out-Null
 Assert (Test-AppliedMarker $marker $meta) 'Reapply did not recreate missing metadata after verification'
 [IO.File]::WriteAllText($target,'unknown updated archive')
 Throws {Set-BlockerArchive $target $exe $preparation Restore} 'Unknown update was overwritten'
 Assert ([IO.File]::ReadAllText($target) -eq 'unknown updated archive') 'Unknown update was changed'
 Copy-Item (Join-Path $preparation 'blocked.asar') $target -Force
 [IO.File]::WriteAllText($exe,'unknown executable update')
 Throws {Set-BlockerArchive $target $exe $preparation Apply} 'Changed executable accepted'
 [IO.File]::WriteAllText($exe,'fixture executable 99.1.0')
 [IO.File]::WriteAllText((Join-Path $preparation 'original.asar'),'corrupted rollback')
 Throws {Set-BlockerArchive $target $exe $preparation Restore} 'Corrupt rollback accepted'
 Copy-Item -LiteralPath $result.Backup -Destination (Join-Path $preparation 'original.asar') -Force
 Remove-Item -LiteralPath (Join-Path $preparation 'blocked.asar')
 Set-BlockerArchive $target $exe $preparation Restore | Out-Null
 Assert (!(Test-Path $marker) -and (Read-Hash $target) -eq $meta.originalAsarSha256) 'Restore did not restore original and remove marker'
 $again=Set-BlockerArchive $target $exe $preparation Restore
 Assert (!$again.Backup) 'Restore was not idempotent'
 Assert (Test-Path $result.Backup) 'Prior atomic backup was lost'
 # Execute the real early-failure reporting path in this PowerShell edition, in scratch only.
 $reportRoot=Join-Path $scratch 'report-private-serial'
 New-Item -ItemType Directory -Path $reportRoot | Out-Null
 foreach($file in @('Prepare.ps1','BladeBlocker.ps1','Blocker.Common.ps1','failure-report.cjs','package.json')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $reportRoot}
 foreach($entry in @('Prepare.ps1','BladeBlocker.ps1')){
  $ErrorActionPreference='Continue'
  try{& $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $reportRoot $entry) -InstallDirectory (Join-Path $scratch 'private-serial-invalid') *> (Join-Path $scratch 'failure-output.txt')}finally{$ErrorActionPreference='Stop'}
  Assert ($LASTEXITCODE -ne 0) 'Invalid installation unexpectedly succeeded'
 }
 $reports=@(Get-ChildItem -LiteralPath (Join-Path $reportRoot 'diagnostics') -Filter '*.md')
 Assert ($reports.Count -eq 2) 'Early discovery failures did not produce both reports'
 foreach($report in $reports){
  $text=Get-Content -LiteralPath $report.FullName -Raw
  Assert ($text.Contains('- PowerShell: '+$PSVersionTable.PSVersion.ToString())) 'Early report lost PowerShell version'
  Assert ($text.Contains('- Archive SHA-256: unavailable') -and $text.Contains('- Executable SHA-256: unavailable')) 'Early report misbound missing artifact arguments'
  Assert (!$text.Contains($scratch) -and $text -notmatch 'private-serial|Expected a standard') 'Early report leaked private path or exception'
 }
 # The child failures were expected; do not propagate their native exit code to CI.
 $global:LASTEXITCODE=0
 Write-Output ('Passed in PowerShell '+$PSVersionTable.PSVersion+' ('+[TimeZoneInfo]::Local.Id+'): offline package version, discovery, relative provider paths, future version, apply/restore, UTC marker contract, future rejection, idempotence, backup/update safety, early-report privacy and runtime version.')
}finally{
 $env:ProgramFiles=$oldProgramFiles
 $resolved=[IO.Path]::GetFullPath($scratch)
 if($resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved).StartsWith('blocker-operations-')){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
