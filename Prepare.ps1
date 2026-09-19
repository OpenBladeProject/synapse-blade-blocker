$ErrorActionPreference='Stop'
$install='C:\Program Files\Razer\RazerAppEngine\app-4.0.821'
$meta=Get-Content (Join-Path $PSScriptRoot 'source-metadata.json') -Raw | ConvertFrom-Json
$archive=Join-Path $install 'resources\app.asar'
if((Get-FileHash (Join-Path $install 'RazerAppEngine.exe')).Hash -ne $meta.exeSha256){throw 'Unsupported Synapse executable; no patch prepared'}
if((Get-FileHash $archive).Hash -ne $meta.sourceAsarSha256){throw 'Expected original Synapse archive; restore before preparing'}
$local=Join-Path $PSScriptRoot 'original.asar'
if((Test-Path $local) -and (Get-FileHash $local).Hash -ne $meta.sourceAsarSha256){throw 'Different local original.asar exists; preserve it'}
Copy-Item -LiteralPath $archive -Destination $local
& node (Join-Path $PSScriptRoot 'build-prototype-blades.cjs')
if($LASTEXITCODE -ne 0){throw 'Build failed'}
$built=Join-Path $PSScriptRoot 'patched-blades.offline-only.asar'
if((Get-FileHash $built).Hash -ne '3FA3CD488659D6C36CD8B8DA580CF57F5873F5BB1769A3CB016DF667B54CFE5F'){throw 'Unexpected build output; do not apply'}
Copy-Item $built (Join-Path $PSScriptRoot 'blocked.asar')
Write-Output 'Prepared locally. Installed Synapse has not been modified.'
