# CrowdStrike Sentinel Connector - Definition Deployment Script
# This script deploys the connector definition and polling configuration

param(
    [string]$ConfigFile = "generated-config.json"
)

# Check if infrastructure has been deployed
if (-not (Test-Path $ConfigFile)) {
    Write-Host "ERROR: $ConfigFile not found. Run deploy-infrastructure.ps1 first!" -ForegroundColor Red
    exit 1
}

# Read generated configuration
Write-Host "Reading configuration from $ConfigFile..." -ForegroundColor Cyan
$config = Get-Content $ConfigFile | ConvertFrom-Json

$subscriptionId = $config.subscription_id
$resourceGroup = $config.resource_group
$workspaceName = $config.workspace_name
$location = $config.location
$dceEndpoint = $config.dce_endpoint
$dcrImmutableId = $config.dcr_immutable_id
$csApiBase = $config.crowdstrike_api_base
$csClientId = $config.crowdstrike_client_id
$csClientSecret = $config.crowdstrike_client_secret

Write-Host "`nDeploying CrowdStrike connector definition to:" -ForegroundColor Cyan
Write-Host "  Subscription: $subscriptionId" -ForegroundColor White
Write-Host "  Resource Group: $resourceGroup" -ForegroundColor White
Write-Host "  Workspace: $workspaceName" -ForegroundColor White

# Set Azure context
Write-Host "`nSetting Azure subscription context..." -ForegroundColor Cyan
az account set --subscription $subscriptionId

# Get workspace resource ID and determine base URL
$workspaceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$workspaceName"

# Determine Azure cloud endpoint and resource based on location
if ($location -like "*usgov*" -or $location -like "*usdod*") {
    $baseUrl = "https://management.usgovcloudapi.net"
    $resource = "https://management.usgovcloudapi.net/"
} else {
    $baseUrl = "https://management.azure.com"
    $resource = "https://management.azure.com/"
}

# Update CrowdStrikeAPI_Definition.json
Write-Host "`nPreparing connector definition..." -ForegroundColor Cyan
$definitionTemplate = Get-Content "CrowdStrikeAPI_Definition.json" | ConvertFrom-Json

# For REST API deployment, we only need properties and location
$definitionBody = @{
    location = $location
    kind = "Customizable"
    properties = $definitionTemplate.properties
}

$definitionBody | ConvertTo-Json -Depth 20 | Set-Content "definition_temp.json"

# Deploy Connector Definition
Write-Host "Deploying connector definition..." -ForegroundColor Cyan
$definitionName = "CrowdStrikeAPICCPDefinition"
$apiVersion = "2024-09-01"
$definitionUrl = "$baseUrl$workspaceId/providers/Microsoft.SecurityInsights/dataConnectorDefinitions/$definitionName`?api-version=$apiVersion"
Write-Host "DEBUG URL: $definitionUrl" -ForegroundColor Yellow

$definitionResult = az rest --method PUT `
    --url $definitionUrl `
    --body '@definition_temp.json' `
    --headers "Content-Type=application/json" `
    --resource $resource

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create connector definition" -ForegroundColor Red
    Remove-Item "definition_temp.json" -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "Connector definition created successfully!" -ForegroundColor Green

# Clean up temporary files
Remove-Item "definition_temp.json" -ErrorAction SilentlyContinue

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Connector definition deployment complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "Deploy the 5 data connectors: .\deploy-all.ps1" -ForegroundColor White
Write-Host ""
