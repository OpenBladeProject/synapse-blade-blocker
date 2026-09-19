$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Blocker.Common.ps1')
function Assert($Condition,[string]$Message){if(!$Condition){throw $Message}}
function Throws([scriptblock]$Action,[string]$Message){$failed=$false;try{& $Action | Out-Null}catch{$failed=$true};Assert $failed $Message}
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('blocker-operations-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
$oldProgramFiles=$env:ProgramFiles
try{
 $env:ProgramFiles=Join-Path $scratch 'ProgramFiles'
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
 $result=Set-BlockerArchive $target $exe $preparation Apply
 $marker=Join-Path $install 'resources\synapse-blade-blocker.json'
 Assert $result.Success 'Apply failed'
 Assert ((Read-Hash $result.Backup) -eq $meta.originalAsarSha256) 'Original atomic backup was not preserved'
 $applied=Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
 Assert (Test-AppliedMarker $marker $meta) 'Applied marker did not verify'
 Assert (($applied.PSObject.Properties.Name | Sort-Object) -join ',' -eq 'appliedAtUtc,archiveSha256,bladeProductIds,executableSha256,patchId,schemaVersion') 'Sidecar fields differ from agreed contract'
 $markerHash=Read-Hash $marker
 $again=Set-BlockerArchive $target $exe $preparation Apply
 Assert (!$again.Backup -and (Read-Hash $marker) -eq $markerHash) 'Reapply was not idempotent'
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
 Write-Output 'Passed: discovery, active path, future version, bounded explicit path, apply, marker contract, idempotence, missing-marker repair, unknown archive/executable preservation, corrupt rollback, restore without patch, backup preservation.'
}finally{
 $env:ProgramFiles=$oldProgramFiles
 $resolved=[IO.Path]::GetFullPath($scratch)
 if($resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved).StartsWith('blocker-operations-')){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
