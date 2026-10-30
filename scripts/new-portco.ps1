# Scaffolds a PortCo's own portal repo from templates/portco-site.
# Usage (PowerShell, from C:\repo\Zudoku):
#   .\scripts\new-portco.ps1 -Id scb -Label SCB
# Creates C:\repo\portal-<id> with its first commit. Push it to GitHub, then run
# .\scripts\onboard-portco.ps1 to give its pipeline access to its folder.
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$Id,
    [Parameter(Mandatory)][string]$Label,
    [string]$Destination = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "portal-$Id")
)
$ErrorActionPreference = "Stop"
$hub = Split-Path $PSScriptRoot -Parent
$registry = Get-Content (Join-Path $hub "sections.json") -Raw | ConvertFrom-Json

if (Test-Path $Destination) { throw "$Destination already exists" }
Copy-Item (Join-Path $hub "templates\portco-site") $Destination -Recurse
New-Item (Join-Path $Destination "portal") -ItemType Directory | Out-Null
Copy-Item (Join-Path $hub "portal\portal.ts") (Join-Path $Destination "portal\portal.ts")

$tokens = @{ "__ID__" = $Id; "__LABEL__" = $Label; "__PORTAL_URL__" = $registry.portalUrl }
Get-ChildItem $Destination -Recurse -File | ForEach-Object {
    $text = Get-Content $_.FullName -Raw
    $new = $text
    foreach ($k in $tokens.Keys) { $new = $new.Replace($k, $tokens[$k]) }
    if ($new -ne $text) { [IO.File]::WriteAllText($_.FullName, $new) }
}

Push-Location $Destination
try {
    npm install
    if ($LASTEXITCODE) { throw "npm install failed" }
    git init -b main -q
    git add -A
    git commit -q -m "Scaffold $Label portal section"
} finally { Pop-Location }

if (-not ($registry.sections | Where-Object id -eq $Id)) {
    Write-Warning "'$Id' is not in sections.json yet. Add it to the hub so other sections link to it."
}
Write-Host "Created $Destination"
Write-Host "Next: create the GitHub repo and push, e.g.  gh repo create <owner>/portal-$Id --private --source=$Destination --push"
