[CmdletBinding()]
param([string]$InstallDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Blocker.Common.ps1')
$toolVersion=Get-ToolVersion
try {
$env:BLOCKER_POWERSHELL_VERSION=$PSVersionTable.PSVersion.ToString()
$install=Resolve-AppEngine $InstallDirectory
$archive=Join-Path $install 'resources\app.asar'
$exe=Join-Path $install 'RazerAppEngine.exe'
$before=Read-Hash $archive
$exeBefore=Read-Hash $exe
# Every attempt uses a fresh directory. Earlier preparations and original.asar are never overwritten.
$output=Join-Path $PSScriptRoot ('prepared\'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff')+'-'+[guid]::NewGuid().ToString('N'))
& node (Join-Path $PSScriptRoot 'build-prototype-blades.cjs') $archive $exe $output
if($LASTEXITCODE -ne 0){$builderReported=$true;throw 'Preparation failed. Report compatibility issues at https://github.com/OSSBlade/synapse-blade-blocker/issues'}
$m=Read-Preparation $output
if((Read-Hash $archive) -ne $before -or (Read-Hash $exe) -ne $exeBefore -or $m.originalAsarSha256 -ne $before -or $m.executableSha256 -ne $exeBefore){throw 'Installation changed during preparation; this output cannot be applied to the changed installation.'}
[pscustomobject]@{ToolVersion=$toolVersion;Prepared=$true;Installation=$install;PreparationDirectory=$output;InstalledFilesModified=$false}

}catch{
 try { if(!$builderReported){ & node (Join-Path $PSScriptRoot 'failure-report.cjs') '--stage=Prepare' ('--error='+$_.Exception.Message) ('--archive='+$archive) ('--executable='+$exe) ('--psVersion='+$PSVersionTable.PSVersion.ToString()) } } catch { Write-Warning 'Diagnostic reporting failed; the original error follows.' }
 throw
}
