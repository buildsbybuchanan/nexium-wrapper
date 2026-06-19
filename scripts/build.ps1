$ErrorActionPreference = "Stop"
Set-Location (Resolve-Path (Join-Path $PSScriptRoot ".."))
& npm.cmd install
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& npm.cmd run tauri build
exit $LASTEXITCODE
