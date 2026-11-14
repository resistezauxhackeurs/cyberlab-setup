[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("windows-server", "windows-client", "windows-ad")]
    [string]$Role
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script = Join-Path $Root "windows\$Role\install.ps1"

if (-not (Test-Path -LiteralPath $Script)) {
    throw "Script introuvable pour le rôle '$Role' : $Script"
}

Write-Host "[+] Préparation du rôle : $Role"
& $Script
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "Le script du rôle a retourné le code $LASTEXITCODE"
}
