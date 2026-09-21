param(
    [string]$File = 'assets/environment/snow-fortress/entrance-kit-v1/exports/SnowFortress_ReviewSlice.glb',
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'upload_asset.py'
if ($DryRun) {
    & python $scriptPath --file $File --dry-run
    exit $LASTEXITCODE
}
$credentialPath = Join-Path $env:LOCALAPPDATA 'RobloxCodex/asset-upload.clixml'
if (-not (Test-Path -LiteralPath $credentialPath)) {
    throw 'No upload credential configured. Run tools/roblox/configure_upload.ps1 in your PowerShell terminal first.'
}
$credential = Import-Clixml -LiteralPath $credentialPath
$previousKey = $env:ROBLOX_OPEN_CLOUD_API_KEY
$previousType = $env:ROBLOX_CREATOR_TYPE
$previousId = $env:ROBLOX_CREATOR_ID
$secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.ApiKey)
try {
    $env:ROBLOX_OPEN_CLOUD_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPointer)
    $env:ROBLOX_CREATOR_TYPE = $credential.CreatorType
    $env:ROBLOX_CREATOR_ID = $credential.CreatorId
    & python $scriptPath --file $File
    $uploadExitCode = $LASTEXITCODE
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPointer)
    $env:ROBLOX_OPEN_CLOUD_API_KEY = $previousKey
    $env:ROBLOX_CREATOR_TYPE = $previousType
    $env:ROBLOX_CREATOR_ID = $previousId
}
exit $uploadExitCode
