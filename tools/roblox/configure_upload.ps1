# Run in your own PowerShell terminal; the API key is entered through a masked prompt.
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This credential store requires Windows DPAPI.' }
$creatorType = (Read-Host 'Asset owner type (user or group)').Trim().ToLowerInvariant()
if ($creatorType -notin @('user', 'group')) { throw 'Owner type must be user or group.' }
$creatorId = (Read-Host "Roblox $creatorType ID (numeric, from its profile URL)").Trim()
if ($creatorId -notmatch '^[1-9][0-9]*$') { throw 'A positive numeric Roblox owner ID is required.' }
$apiKey = Read-Host 'Open Cloud API key (Assets Read and Write)' -AsSecureString
if ($apiKey.Length -eq 0) { throw 'The key cannot be empty.' }
$credentialDirectory = Join-Path $env:LOCALAPPDATA 'RobloxCodex'
New-Item -ItemType Directory -Path $credentialDirectory -Force | Out-Null
$credentialPath = Join-Path $credentialDirectory 'asset-upload.clixml'
[pscustomobject]@{ CreatorType = $creatorType; CreatorId = $creatorId; ApiKey = $apiKey } |
    Export-Clixml -LiteralPath $credentialPath
Write-Host 'Saved upload credentials encrypted for your Windows account, outside the repository.'
Write-Host "Asset owner: $creatorType $creatorId"
