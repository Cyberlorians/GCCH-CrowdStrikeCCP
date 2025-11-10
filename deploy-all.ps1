# CrowdStrike Sentinel Connector - Deploy All Connectors
# Deploys all 5 CrowdStrike data connectors

param(
    [string]$ConfigFile = "generated-config.json"
)

$ErrorActionPreference = "Stop"

# Check if infrastructure and definition have been deployed
if (-not (Test-Path $ConfigFile)) {
    Write-Host "ERROR: $ConfigFile not found." -ForegroundColor Red
    Write-Host "Please run these scripts first:" -ForegroundColor Yellow
    Write-Host "  1. .\deploy-infrastructure.ps1" -ForegroundColor White
    Write-Host "  2. .\deploy-definition.ps1" -ForegroundColor White
    exit 1
}

# Load configuration
Write-Host "Reading configuration from $ConfigFile..." -ForegroundColor Cyan
$config = Get-Content $ConfigFile | ConvertFrom-Json

Write-Host "`nDeploying 5 CrowdStrike connectors..." -ForegroundColor Cyan
Write-Host "  Subscription: $($config.subscription_id)" -ForegroundColor White
Write-Host "  Workspace: $($config.workspace_name)" -ForegroundColor White

# Determine Azure environment based on location
$isGovCloud = $config.location -match "usgov" # Check if Azure Government region
$baseUrl = if ($isGovCloud) {
    "https://management.usgovcloudapi.net"
} else {
    "https://management.azure.com"
}

$workspaceUrl = "$baseUrl/subscriptions/$($config.subscription_id)/resourceGroups/$($config.resource_group)/providers/Microsoft.OperationalInsights/workspaces/$($config.workspace_name)/providers/Microsoft.SecurityInsights/dataConnectors"

# Deploy each connector
$connectors = @(
    @{Name="Vulnerabilities"; File="deploy-vulnerabilities.json"; PathKey="api_vulnerabilities_path"},
    @{Name="Alerts"; File="deploy-alerts.json"; PathKey="api_alerts_path"},
    @{Name="Incidents"; File="deploy-incidents.json"; PathKey="api_incidents_path"},
    @{Name="Detections"; File="deploy-detections.json"; PathKey="api_detections_path"},
    @{Name="Hosts"; File="deploy-hosts.json"; PathKey="api_hosts_path"}
)

$successCount = 0
foreach ($connector in $connectors) {
    Write-Host "`nDeploying $($connector.Name) connector..." -ForegroundColor Yellow
    
    # Generate unique connector ID
    $connectorId = "CrowdStrike$($connector.Name)Poller"
    
    # Update JSON with config values
    $json = Get-Content $connector.File -Raw | ConvertFrom-Json
    $json.properties.auth.ClientId = $config.crowdstrike_client_id
    $json.properties.auth.ClientSecret = $config.crowdstrike_client_secret
    $json.properties.auth.tokenEndpoint = "$($config.crowdstrike_api_base)/oauth2/token"
    $json.properties.dcrConfig.dataCollectionEndpoint = $config.dce_endpoint
    $json.properties.dcrConfig.dataCollectionRuleImmutableId = $config.dcr_immutable_id
    
    # Update API endpoint using path from config
    $apiPath = $config.($connector.PathKey)
    if ($apiPath) {
        $json.properties.request.apiEndpoint = "$($config.crowdstrike_api_base)$apiPath"
    } else {
        # Fallback: just replace base URL if path not configured
        $endpoint = $json.properties.request.apiEndpoint
        $json.properties.request.apiEndpoint = $endpoint -replace "https://[^/]+", $config.crowdstrike_api_base
    }
    
    # Save temp file
    $tempFile = "temp-$($connector.Name).json"
    $json | ConvertTo-Json -Depth 10 | Set-Content $tempFile
    
    # Deploy
    try {
        az rest --method PUT `
            --url "$workspaceUrl/$connectorId`?api-version=2024-09-01" `
            --body "@$tempFile" `
            --headers "Content-Type=application/json" | Out-Null
        
        Write-Host "  ✓ $($connector.Name) deployed successfully" -ForegroundColor Green
        $successCount++
        
        # Update the original JSON file with current values so it stays in sync
        $json | ConvertTo-Json -Depth 10 | Set-Content $connector.File
    }
    catch {
        Write-Host "  ✗ $($connector.Name) failed: $_" -ForegroundColor Red
    }
    finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Deployment complete! ($successCount/5 connectors)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nConnectors will start polling within 5 minutes." -ForegroundColor Cyan
Write-Host "Check data ingestion in Sentinel Log Analytics:" -ForegroundColor Cyan
Write-Host "  - CrowdStrikeVulnerabilities" -ForegroundColor White
Write-Host "  - CrowdStrikeAlerts" -ForegroundColor White
Write-Host "  - CrowdStrikeIncidents" -ForegroundColor White
Write-Host "  - CrowdStrikeDetections" -ForegroundColor White
Write-Host "  - CrowdStrikeHosts" -ForegroundColor White
Write-Host ""

