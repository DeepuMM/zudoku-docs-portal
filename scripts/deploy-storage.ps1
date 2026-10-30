# Builds the Zudoku site and publishes it to an Azure Storage static website ($web).
# Usage (PowerShell, from C:\repo\Zudoku):  .\scripts\deploy-storage.ps1
param(
    [string]$Subscription   = "scbx-testing",
    [string]$ResourceGroup  = "rg-zudoku-docs",
    [string]$StorageAccount = "stzudokudocs20683",
    [string]$Location       = "southeastasia",
    [switch]$SkipBuild
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

az account set --subscription $Subscription

# 1. Make sure the resource group, account and static website exist.
if (-not (az group exists -n $ResourceGroup | ConvertFrom-Json)) {
    az group create -n $ResourceGroup -l $Location -o none
}
if (-not (az storage account show -n $StorageAccount -g $ResourceGroup --query id -o tsv 2>$null)) {
    az storage account create -n $StorageAccount -g $ResourceGroup -l $Location `
        --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 `
        --allow-blob-public-access false -o none
}
az storage blob service-properties update --account-name $StorageAccount --auth-mode login `
    --static-website --index-document index.html --404-document 404.html -o none

# 2. Give the signed-in user write access to blobs (no-op if already assigned).
$scope = az storage account show -n $StorageAccount -g $ResourceGroup --query id -o tsv
$me    = az ad signed-in-user show --query id -o tsv
$has   = az role assignment list --assignee $me --scope $scope --role "Storage Blob Data Contributor" --query "[].id" -o tsv
if (-not $has) {
    az role assignment create --assignee-object-id $me --assignee-principal-type User `
        --role "Storage Blob Data Contributor" --scope $scope -o none
    Write-Host "Role assigned; waiting 60s for it to take effect..."
    Start-Sleep -Seconds 60
}

# 3. Build.
if (-not $SkipBuild) { npm run build; if ($LASTEXITCODE) { throw "build failed" } }

# 4. Stage: the static site (minus the SSR server bundle), plus extensionless
#    copies of every page so direct links like /architecture/overview work.
$stage  = Join-Path $env:TEMP "zudoku-deploy"
$site   = Join-Path $stage "site"
$routes = Join-Path $stage "routes"
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item $site, $routes -ItemType Directory | Out-Null
Copy-Item "dist\*" $site -Recurse -Exclude "server"
Remove-Item (Join-Path $site "server") -Recurse -Force -ErrorAction SilentlyContinue

Get-ChildItem $site -Recurse -Filter *.html | Where-Object Name -ne "index.html" | ForEach-Object {
    $rel  = $_.FullName.Substring($site.Length + 1)
    $base = $rel.Substring(0, $rel.Length - 5)            # strip .html
    if (Test-Path (Join-Path $site $base) -PathType Container) {
        $dest = Join-Path $routes "$base\index.html"      # e.g. api.html -> api/index.html
    } else {
        $dest = Join-Path $routes $base                   # e.g. architecture/overview
    }
    New-Item (Split-Path $dest) -ItemType Directory -Force | Out-Null
    Copy-Item $_.FullName $dest
}

# 5. Upload. Extensionless copies need an explicit HTML content type.
az storage blob upload-batch --account-name $StorageAccount --auth-mode login `
    -d '$web' -s $site --overwrite -o none
if ($LASTEXITCODE) { throw "upload of site files failed" }
az storage blob upload-batch --account-name $StorageAccount --auth-mode login `
    -d '$web' -s $routes --overwrite --content-type "text/html; charset=utf-8" -o none
if ($LASTEXITCODE) { throw "upload of extensionless routes failed" }

$url = az storage account show -n $StorageAccount -g $ResourceGroup --query primaryEndpoints.web -o tsv
Write-Host "Published: $url"
