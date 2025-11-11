# Cleanup Script - Delete CrowdStrike Connector Infrastructure (No DCE)
# This removes all connector resources for clean redeployment test
# Reads from config.json and generated-config.json to delete exactly what was deployed

$ErrorActionPreference = "Continue"

# Load configuration
if (-not (Test-Path "config.json")) {
    Write-Host "ERROR: config.json not found!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "generated-config.json")) {
    Write-Host "ERROR: generated-config.json not found! Nothing to clean up." -ForegroundColor Red
    Write-Host "Run .\deploy-infrastructure.ps1 first to create resources." -ForegroundColor Yellow
    exit 1
}

$config = Get-Content "config.json" | ConvertFrom-Json
$generated = Get-Content "generated-config.json" | ConvertFrom-Json

$subscriptionId = $config.subscription_id
$resourceGroup = $config.resource_group
$workspaceName = $config.workspace_name
$location = $config.location

# Get resource IDs from generated config
$dcrResourceId = $generated.dcr_resource_id
$dcrName = $dcrResourceId -replace ".*/", ""

# Determine cloud environment from location
$cloudEnv = if ($location -match "usgov") { "AzureUSGovernment" } else { "AzureCloud" }
$baseUrl = if ($cloudEnv -eq "AzureUSGovernment") { "https://management.usgovcloudapi.net" } else { "https://management.azure.com" }

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CrowdStrike Connector Cleanup (No DCE)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will DELETE the following:" -ForegroundColor Yellow
Write-Host "  • 5 Data Connectors" -ForegroundColor White
Write-Host "  • Connector Definition" -ForegroundColor White
Write-Host "  • Data Collection Rule (DCR): $dcrName" -ForegroundColor White
Write-Host ""
Write-Host "Environment: $cloudEnv" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Cyan
Write-Host "Workspace: $workspaceName" -ForegroundColor Cyan
Write-Host ""
Write-Host "Mock API will NOT be touched!" -ForegroundColor Green
Write-Host ""

$confirmation = Read-Host "Type 'DELETE' to confirm"
if ($confirmation -ne "DELETE" -and $confirmation -ne "delete") {
    Write-Host "Cleanup cancelled." -ForegroundColor Yellow
    exit 0
}

# Set Azure context
Write-Host "`nSetting Azure context..." -ForegroundColor Cyan
az cloud set --name $cloudEnv | Out-Null
az account set --subscription $subscriptionId | Out-Null

$workspaceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$workspaceName"

# Delete 5 Connectors using REST API
Write-Host "`n[1/3] Deleting 5 data connectors..." -ForegroundColor Cyan
$connectors = @(
    "CrowdStrikeVulnerabilitiesPoller",
    "CrowdStrikeAlertsPoller",
    "CrowdStrikeIncidentsPoller",
    "CrowdStrikeDetectionsPoller",
    "CrowdStrikeHostsPoller"
)

foreach ($connector in $connectors) {
    $url = "$baseUrl$workspaceId/providers/Microsoft.SecurityInsights/dataConnectors/$connector`?api-version=2023-02-01"
    $result = az rest --method DELETE --url $url 2>&1
    if ($LASTEXITCODE -eq 0 -or $result -like "*NotFound*") {
        Write-Host "  ✓ Deleted $connector" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ $connector not found" -ForegroundColor Yellow
    }
}

# Delete Connector Definition using REST API
Write-Host "`n[2/3] Deleting connector definition..." -ForegroundColor Cyan
$url = "$baseUrl$workspaceId/providers/Microsoft.SecurityInsights/dataConnectorDefinitions/CrowdStrikeAPICCPDefinition?api-version=2024-09-01"
$result = az rest --method DELETE --url $url 2>&1
if ($LASTEXITCODE -eq 0 -or $result -like "*NotFound*") {
    Write-Host "  ✓ Deleted CrowdStrikeAPICCPDefinition" -ForegroundColor Green
}

# Delete DCR using REST API with full resource ID
Write-Host "`n[3/3] Deleting Data Collection Rule..." -ForegroundColor Cyan
$dcrUrl = "$baseUrl$dcrResourceId`?api-version=2023-03-11"
$result = az rest --method DELETE --url $dcrUrl 2>&1
if ($LASTEXITCODE -eq 0 -or $result -like "*NotFound*") {
    Write-Host "  ✓ Deleted DCR: $dcrName" -ForegroundColor Green
} else {
    Write-Host "  ⚠ DCR deletion failed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✓ Cleanup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Verify everything is actually deleted
Write-Host "Verifying cleanup..." -ForegroundColor Cyan

# Check connectors using comprehensive API query
$connectorsUrl = "$baseUrl$workspaceId/providers/Microsoft.SecurityInsights/dataConnectors?api-version=2024-09-01"
$connectorsCheck = az rest --method GET --url $connectorsUrl 2>&1 | ConvertFrom-Json
$crowdstrikeConnectors = $connectorsCheck.value | Where-Object { $_.name -like "*CrowdStrike*" }
if ($crowdstrikeConnectors) {
    Write-Host "  ⚠ Warning: $($crowdstrikeConnectors.Count) CrowdStrike connector(s) still exist:" -ForegroundColor Yellow
    $crowdstrikeConnectors | ForEach-Object { Write-Host "    - $($_.name) (kind: $($_.kind))" -ForegroundColor Yellow }
} else {
    Write-Host "  ✓ All 5 connectors deleted" -ForegroundColor Green
}

# Check DCR
$dcrCheckUrl = "$baseUrl$dcrResourceId`?api-version=2023-03-11"
$dcrCheck = az rest --method GET --url $dcrCheckUrl 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ⚠ Warning: DCR still exists" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ DCR deleted" -ForegroundColor Green
}

Write-Host ""
Write-Host "Environment is clean. Ready for fresh deployment!" -ForegroundColor Cyan
Write-Host ""
Write-Host "NOTE: No DCE used in this deployment - DCR has Direct kind" -ForegroundColor Yellow
Write-Host ""
Write-Host "To redeploy, run:" -ForegroundColor White
Write-Host "  .\deploy-infrastructure.ps1" -ForegroundColor Yellow
Write-Host "  .\deploy-definition.ps1" -ForegroundColor Yellow
Write-Host "  .\deploy-all.ps1" -ForegroundColor Yellow
Write-Host ""
