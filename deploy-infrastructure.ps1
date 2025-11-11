# CrowdStrike Sentinel Connector - Infrastructure Deployment Script (No DCE)
# This script creates the DCR resource needed for the connectors

param(
    [string]$ConfigFile = "config.json"
)

# Read customer configuration
Write-Host "Reading configuration from $ConfigFile..." -ForegroundColor Cyan
$config = Get-Content $ConfigFile | ConvertFrom-Json

$subscriptionId = $config.subscription_id
$resourceGroup = $config.resource_group
$workspaceName = $config.workspace_name
$location = $config.location

# Validate required fields
if ($subscriptionId -eq "YOUR_AZURE_SUBSCRIPTION_ID" -or
    $resourceGroup -eq "YOUR_RESOURCE_GROUP_NAME" -or
    $workspaceName -eq "YOUR_SENTINEL_WORKSPACE_NAME" -or
    $location -eq "YOUR_AZURE_REGION") {
    Write-Host "ERROR: Please edit config.json and fill in all values" -ForegroundColor Red
    exit 1
}

Write-Host "`nDeploying CrowdStrike infrastructure to:" -ForegroundColor Cyan
Write-Host "  Subscription: $subscriptionId" -ForegroundColor White
Write-Host "  Resource Group: $resourceGroup" -ForegroundColor White
Write-Host "  Workspace: $workspaceName" -ForegroundColor White
Write-Host "  Location: $location" -ForegroundColor White

# Set Azure context
Write-Host "`nSetting Azure subscription context..." -ForegroundColor Cyan
az account set --subscription $subscriptionId

# Get workspace resource ID
Write-Host "Getting Sentinel workspace information..." -ForegroundColor Cyan
$workspaceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$workspaceName"

# Verify workspace exists
$baseUrl = if ($location -match "usgov") { "https://management.usgovcloudapi.net" } else { "https://management.azure.com" }
$workspaceCheck = az rest --method GET --url "$baseUrl$workspaceId`?api-version=2022-10-01" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Could not find workspace $workspaceName in resource group $resourceGroup" -ForegroundColor Red
    exit 1
}

Write-Host "Found workspace: $workspaceId" -ForegroundColor Green

# Deploy Data Collection Rule (DCR) with Direct kind
Write-Host "`nDeploying Data Collection Rule (DCR)..." -ForegroundColor Cyan
# Use custom name if provided, otherwise auto-generate with random suffix
$randomSuffix = -join ((97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})
if ($config.dcr_name -and $config.dcr_name.Trim() -ne "") {
    $dcrName = $config.dcr_name.Trim()
    Write-Host "  Using custom DCR name: $dcrName" -ForegroundColor Yellow
} else {
    $dcrName = "CrowdStrikeAPICCP-$randomSuffix"
    Write-Host "  Auto-generated DCR name: $dcrName" -ForegroundColor Cyan
}

# Read DCR template and update workspace ID
$dcrTemplate = Get-Content "CrowdStrikeAPI_DCR.json" | ConvertFrom-Json
$dcrTemplate[0].properties.destinations.logAnalytics[0].workspaceResourceId = $workspaceId

# For REST API, we need to restructure - only properties, location, and kind at root
$dcrBody = @{
    location = $location
    kind = "Direct"
    properties = $dcrTemplate[0].properties
}
$dcrBody | ConvertTo-Json -Depth 20 | Set-Content "dcr_temp.json"

$dcrResult = az rest --method PUT `
    --url "$baseUrl/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$dcrName`?api-version=2023-03-11" `
    --body '@dcr_temp.json' `
    --headers "Content-Type=application/json" 2>&1

Remove-Item "dcr_temp.json" -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create DCR" -ForegroundColor Red
    Write-Host "Result: $dcrResult" -ForegroundColor Yellow
    exit 1
}

# Parse the result and extract immutableId and logsIngestion endpoint
$dcrObject = $dcrResult | ConvertFrom-Json
$dcrImmutableId = $dcrObject.properties.immutableId
$dcrLogsEndpoint = $dcrObject.properties.endpoints.logsIngestion

if (-not $dcrImmutableId) {
    Write-Host "WARNING: Could not extract immutableId from DCR response" -ForegroundColor Yellow
    Write-Host "Response: $dcrResult" -ForegroundColor Yellow
}
Write-Host "DCR created successfully!" -ForegroundColor Green
Write-Host "  DCR Immutable ID: $dcrImmutableId" -ForegroundColor White
Write-Host "  DCR Logs Endpoint: $dcrLogsEndpoint" -ForegroundColor White

# Create generated-config.json with all values (no DCE)
Write-Host "`nSaving generated configuration..." -ForegroundColor Cyan
$generatedConfig = @{
    subscription_id = $subscriptionId
    resource_group = $resourceGroup
    workspace_name = $workspaceName
    location = $location
    dcr_immutable_id = $dcrImmutableId
    dcr_logs_endpoint = $dcrLogsEndpoint
    dcr_resource_id = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$dcrName"
    crowdstrike_api_base = $config.crowdstrike_api_base
    crowdstrike_client_id = $config.crowdstrike_client_id
    crowdstrike_client_secret = $config.crowdstrike_client_secret
    api_vulnerabilities_path = $config.api_vulnerabilities_path
    api_alerts_path = $config.api_alerts_path
    api_incidents_path = $config.api_incidents_path
    api_detections_path = $config.api_detections_path
    api_hosts_path = $config.api_hosts_path
}

$generatedConfig | ConvertTo-Json -Depth 10 | Set-Content "generated-config.json"

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Infrastructure deployment complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nNOTE: DCE not required - using DCR Direct ingestion endpoint" -ForegroundColor Yellow
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Review generated-config.json to verify values" -ForegroundColor White
Write-Host "2. Deploy the Connector Definition: .\deploy-definition.ps1" -ForegroundColor White
Write-Host "3. Deploy the connectors: .\deploy-all.ps1" -ForegroundColor White
Write-Host ""
