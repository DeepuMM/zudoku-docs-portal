# Gives a PortCo repo's pipeline permission to publish its section, and nothing else.
# Creates an Entra app trusted (OIDC) only for <Repo>'s main branch and grants it
# Storage Blob Data Contributor on the storage account with an ABAC condition
# that limits writes and deletes to $web/<Id>/. Then sets the repo variables.
# Usage (PowerShell, from C:\repo\Zudoku):
#   .\scripts\onboard-portco.ps1 -Id scb -Repo DeepuMM/portal-scb
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$Id,
    [Parameter(Mandatory)][string]$Repo,
    [string]$Branch         = "main",
    [string]$Subscription   = "scbx-testing",
    [string]$ResourceGroup  = "rg-zudoku-docs",
    [string]$StorageAccount = "stzudokudocs20683",
    [string]$RepoIds        # "<ownerId> <repoId>"; looked up with gh when omitted
)
$ErrorActionPreference = "Stop"
az account set --subscription $Subscription
$tenantId = az account show --query tenantId -o tsv
$subId    = az account show --query id -o tsv
$appName  = "gh-portal-$Id-deploy"

# 1. App registration + service principal.
$appId = az ad app list --display-name $appName --query "[0].appId" -o tsv
if (-not $appId) {
    $appId = az ad app create --display-name $appName --query appId -o tsv
    Write-Host "Created app $appName ($appId)"
}
if (-not (az ad sp list --filter "appId eq '$appId'" --query "[0].id" -o tsv)) {
    az ad sp create --id $appId -o none
}
$spId = az ad sp list --filter "appId eq '$appId'" --query "[0].id" -o tsv

# 2. Federated credentials. GitHub may present the name-based or the ID-based subject.
if (-not $RepoIds) {
    $RepoIds = gh api "repos/$Repo" --jq '"\(.owner.id) \(.id)"'
    if ($LASTEXITCODE -or -not $RepoIds) { throw "Could not look up $Repo with gh; pass -RepoIds '<ownerId> <repoId>'" }
}
$owner, $name = $Repo.Split("/")
$ownerId, $repoId = $RepoIds.Split(" ")
$subjects = [ordered]@{
    "github-$Branch"     = "repo:${Repo}:ref:refs/heads/$Branch"
    "github-$Branch-ids" = "repo:$owner@$ownerId/$name@${repoId}:ref:refs/heads/$Branch"
}
foreach ($credName in $subjects.Keys) {
    $subject = $subjects[$credName]
    if (-not (az ad app federated-credential list --id $appId --query "[?subject=='$subject'].name" -o tsv)) {
        $fic = Join-Path $env:TEMP "fic.json"
        @{
            name      = $credName
            issuer    = "https://token.actions.githubusercontent.com"
            subject   = $subject
            audiences = @("api://AzureADTokenExchange")
        } | ConvertTo-Json | Set-Content $fic -Encoding ascii
        az ad app federated-credential create --id $appId --parameters "@$fic" -o none
        Remove-Item $fic
        Write-Host "Added federated credential for $subject"
    }
}

# 3. Blob write limited to $web/<Id>/ (reads are not restricted; the site is public).
$scope = az storage account show -n $StorageAccount -g $ResourceGroup --query id -o tsv
$condition = @"
(
 (
  !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write'})
  AND
  !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action'})
  AND
  !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete'})
 )
 OR
 (
  @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringEquals '`$web'
  AND
  @Resource[Microsoft.Storage/storageAccounts/blobServices/containers/blobs:path] StringStartsWith '$Id/'
 )
)
"@
if (-not (az role assignment list --assignee $spId --scope $scope --role "Storage Blob Data Contributor" --query "[].id" -o tsv)) {
    $body = @{
        properties = @{
            roleDefinitionId = "$scope/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe"
            principalId      = $spId
            principalType    = "ServicePrincipal"
            condition        = $condition
            conditionVersion = "2.0"
            description      = "Publish only to `$web/$Id/"
        }
    } | ConvertTo-Json -Depth 5
    $bodyFile = Join-Path $env:TEMP "role.json"
    Set-Content $bodyFile $body -Encoding utf8
    $assignmentId = [guid]::NewGuid()
    az rest --method put `
        --url "https://management.azure.com$scope/providers/Microsoft.Authorization/roleAssignments/${assignmentId}?api-version=2022-04-01" `
        --body "@$bodyFile" -o none
    if ($LASTEXITCODE) { throw "role assignment failed" }
    Remove-Item $bodyFile
    Write-Host "Granted Storage Blob Data Contributor on $StorageAccount, limited to `$web/$Id/"
}

# 4. Repo variables the PortCo pipeline reads (identifiers, not secrets).
$vars = [ordered]@{
    AZURE_CLIENT_ID       = $appId
    AZURE_TENANT_ID       = $tenantId
    AZURE_SUBSCRIPTION_ID = $subId
    AZURE_STORAGE_ACCOUNT = $StorageAccount
}
foreach ($k in $vars.Keys) {
    gh variable set $k --repo $Repo --body $vars[$k]
    if ($LASTEXITCODE) {
        Write-Warning "gh variable set failed. Set these in $Repo > Settings > Secrets and variables > Actions > Variables:"
        $vars.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Key) = $($_.Value)" }
        break
    }
}
