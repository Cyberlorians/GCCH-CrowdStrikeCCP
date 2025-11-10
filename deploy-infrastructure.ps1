# CrowdStrike Sentinel Connector - Infrastructure Deployment Script
# This script creates the DCE and DCR resources needed for the connectors

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
if ($subscriptionId -eq "YOUR-SUBSCRIPTION-ID" -or 
    $resourceGroup -eq "YOUR-RESOURCE-GROUP" -or 
    $workspaceName -eq "YOUR-SENTINEL-WORKSPACE" -or
    $location -eq "YOUR-AZURE-REGION") {
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

# Get workspace resource ID using REST API
Write-Host "Getting Sentinel workspace information..." -ForegroundColor Cyan
$workspaceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$workspaceName"

# Verify workspace exists
$baseUrl = if ($location -like "*gov*") { "https://management.usgovcloudapi.net" } else { "https://management.azure.com" }
$workspaceCheck = az rest --method GET --url "$baseUrl$workspaceId`?api-version=2022-10-01" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Could not find workspace $workspaceName in resource group $resourceGroup" -ForegroundColor Red
    exit 1
}

Write-Host "Found workspace: $workspaceId" -ForegroundColor Green

# Update CrowdStrikeAPI_DCR.json with workspace ID
Write-Host "`nPreparing DCR configuration..." -ForegroundColor Cyan
$dcrConfig = Get-Content "CrowdStrikeAPI_DCR.json" | ConvertFrom-Json
$dcrConfig.properties.destinations.logAnalytics[0].workspaceResourceId = $workspaceId
$dcrConfig | ConvertTo-Json -Depth 20 | Set-Content "CrowdStrikeAPI_DCR_updated.json"

# Deploy Data Collection Endpoint (DCE)
Write-Host "`nDeploying Data Collection Endpoint (DCE)..." -ForegroundColor Cyan
# Use custom name if provided, otherwise auto-generate with random suffix
$randomSuffix = -join ((97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})
if ($config.dce_name -and $config.dce_name.Trim() -ne "") {
    $dceName = $config.dce_name.Trim()
    Write-Host "  Using custom DCE name: $dceName" -ForegroundColor Yellow
} else {
    $dceName = "dcr-crowdstrike-v2-endpoint-$randomSuffix"
    Write-Host "  Auto-generated DCE name: $dceName" -ForegroundColor Cyan
}
$dceBody = @{
    location = $location
    properties = @{
        networkAcls = @{
            publicNetworkAccess = "Enabled"
        }
    }
} | ConvertTo-Json -Depth 10

# Save to temp file
$dceBody | Set-Content "dce_temp.json"

$dceResult = az rest --method PUT `
    --url "$baseUrl/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/$dceName`?api-version=2022-06-01" `
    --body '@dce_temp.json' `
    --headers "Content-Type=application/json"

Remove-Item "dce_temp.json" -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create DCE" -ForegroundColor Red
    exit 1
}

$dceObject = $dceResult | ConvertFrom-Json
$dceEndpoint = $dceObject.properties.logsIngestion.endpoint
$dceId = $dceObject.id
Write-Host "DCE created successfully!" -ForegroundColor Green
Write-Host "  DCE Endpoint: $dceEndpoint" -ForegroundColor White

# Deploy Data Collection Rule (DCR)
Write-Host "`nDeploying Data Collection Rule (DCR)..." -ForegroundColor Cyan
# Use custom name if provided, otherwise auto-generate with same random suffix
if ($config.dcr_name -and $config.dcr_name.Trim() -ne "") {
    $dcrName = $config.dcr_name.Trim()
    Write-Host "  Using custom DCR name: $dcrName" -ForegroundColor Yellow
} else {
    $dcrName = "CrowdStrikeAPICCP-$randomSuffix"
    Write-Host "  Auto-generated DCR name: $dcrName" -ForegroundColor Cyan
}
$dcrTemplate = Get-Content "CrowdStrikeAPI_DCR_updated.json" | ConvertFrom-Json

# For REST API, we need to restructure - only properties and location at root
$dcrBody = @{
    location = $location
    properties = $dcrTemplate.properties
}
$dcrBody.properties.dataCollectionEndpointId = $dceId
$dcrBody | ConvertTo-Json -Depth 20 | Set-Content "dcr_temp.json"

$dcrResult = az rest --method PUT `
    --url "$baseUrl/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$dcrName`?api-version=2022-06-01" `
    --body '@dcr_temp.json' `
    --headers "Content-Type=application/json" 2>&1

Remove-Item "dcr_temp.json" -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create DCR" -ForegroundColor Red
    Write-Host "Result: $dcrResult" -ForegroundColor Yellow
    exit 1
}

# Parse the result and extract immutableId
$dcrObject = $dcrResult | ConvertFrom-Json
$dcrImmutableId = $dcrObject.properties.immutableId
if (-not $dcrImmutableId) {
    Write-Host "WARNING: Could not extract immutableId from DCR response" -ForegroundColor Yellow
    Write-Host "Response: $dcrResult" -ForegroundColor Yellow
}
Write-Host "DCR created successfully!" -ForegroundColor Green
Write-Host "  DCR Immutable ID: $dcrImmutableId" -ForegroundColor White

# Create generated-config.json with all values including DCE/DCR
Write-Host "`nSaving generated configuration..." -ForegroundColor Cyan
$generatedConfig = @{
    subscription_id = $subscriptionId
    resource_group = $resourceGroup
    workspace_name = $workspaceName
    location = $location
    dce_endpoint = $dceEndpoint
    dce_resource_id = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/$dceName"
    dcr_immutable_id = $dcrImmutableId
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

# Clean up temporary file
Remove-Item "CrowdStrikeAPI_DCR_updated.json" -ErrorAction SilentlyContinue

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Infrastructure deployment complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Review generated-config.json to verify values" -ForegroundColor White
Write-Host "2. Deploy the Connector Definition: .\deploy-definition.ps1" -ForegroundColor White
Write-Host "3. Deploy the connectors: .\deploy-all.ps1" -ForegroundColor White
Write-Host ""
