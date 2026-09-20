# Fixed Apply/Restore entry point. No arbitrary command or script arguments.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('Apply','Restore')][string]$Mode,
 [Parameter(Mandatory=$true)][string]$InstallDirectory,
 [Parameter(Mandatory=$true)][string]$PreparationDirectory
)
$ErrorActionPreference='Stop'
try{
 & (Join-Path $PSScriptRoot 'BladeBlocker.ps1') -Mode $Mode -InstallDirectory $InstallDirectory -PreparationDirectory $PreparationDirectory -Confirm:$false | Out-Null
 exit 0
}catch{exit 1}
