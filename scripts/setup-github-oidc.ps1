# One-time setup so GitHub Actions can deploy to the storage account without secrets.
# Creates an Entra app + service principal trusted (OIDC) only for the repo's main branch,
# grants it Storage Blob Data Contributor on the storage account, and sets the repo variables.
# Usage (PowerShell, from C:\repo\Zudoku):  .\scripts\setup-github-oidc.ps1
param(
    [string]$Subscription   = "scbx-testing",
    [string]$ResourceGroup  = "rg-zudoku-docs",
    [string]$StorageAccount = "stzudokudocs20683",
    [string]$Repo           = "DeepuMM/zudoku-docs-portal",
    [string]$Branch         = "main",
    [string]$AppName        = "gh-zudoku-docs-portal-deploy"
)
$ErrorActionPreference = "Stop"
az account set --subscription $Subscription
$tenantId = az account show --query tenantId -o tsv
$subId    = az account show --query id -o tsv

# 1. App registration + service principal (reused if they already exist).
$appId = az ad app list --display-name $AppName --query "[0].appId" -o tsv
if (-not $appId) {
    $appId = az ad app create --display-name $AppName --query appId -o tsv
    Write-Host "Created app $AppName ($appId)"
}
if (-not (az ad sp list --filter "appId eq '$appId'" --query "[0].id" -o tsv)) {
    az ad sp create --id $appId -o none
}
$spId = az ad sp list --filter "appId eq '$appId'" --query "[0].id" -o tsv

# 2. Federated credential: only workflow runs on $Repo / $Branch can get a token.
$subject = "repo:${Repo}:ref:refs/heads/$Branch"
$existing = az ad app federated-credential list --id $appId --query "[?subject=='$subject'].name" -o tsv
if (-not $existing) {
    $fic = Join-Path $env:TEMP "fic.json"
    @{
        name      = "github-$($Branch -replace '[^a-zA-Z0-9-]', '-')"
        issuer    = "https://token.actions.githubusercontent.com"
        subject   = $subject
        audiences = @("api://AzureADTokenExchange")
    } | ConvertTo-Json | Set-Content $fic -Encoding ascii
    az ad app federated-credential create --id $appId --parameters "@$fic" -o none
    Remove-Item $fic
    Write-Host "Added federated credential for $subject"
}

# 3. Least privilege: blob write on this one storage account only.
$scope = az storage account show -n $StorageAccount -g $ResourceGroup --query id -o tsv
if (-not (az role assignment list --assignee $spId --scope $scope --role "Storage Blob Data Contributor" --query "[].id" -o tsv)) {
    az role assignment create --assignee-object-id $spId --assignee-principal-type ServicePrincipal `
        --role "Storage Blob Data Contributor" --scope $scope -o none
    Write-Host "Granted Storage Blob Data Contributor on $StorageAccount"
}

# 4. Repo variables the workflow reads (identifiers, not secrets).
$vars = [ordered]@{
    AZURE_CLIENT_ID       = $appId
    AZURE_TENANT_ID       = $tenantId
    AZURE_SUBSCRIPTION_ID = $subId
    AZURE_STORAGE_ACCOUNT = $StorageAccount
}
if (Get-Command gh -ErrorAction SilentlyContinue) {
    foreach ($k in $vars.Keys) {
        gh variable set $k --repo $Repo --body $vars[$k]
        if ($LASTEXITCODE) { throw "gh variable set failed; run 'gh auth login' and re-run this script" }
    }
    Write-Host "Set repo variables on $Repo"
} else {
    Write-Host "gh CLI not found; set these repo variables in GitHub > Settings > Secrets and variables > Actions > Variables:"
    $vars.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Key) = $($_.Value)" }
}
