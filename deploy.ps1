# CrowdStrike Sentinel Connector - Master Deployment Script (No DCE)
# This script orchestrates the complete deployment in one command

param(
    [string]$ConfigFile = "config.json"
)

$ErrorActionPreference = "Stop"

Write-Host @"
========================================
CrowdStrike Sentinel Connector
Complete Deployment (No DCE Required)
========================================
"@ -ForegroundColor Cyan

# Check if config exists
if (-not (Test-Path $ConfigFile)) {
    Write-Host "ERROR: $ConfigFile not found!" -ForegroundColor Red
    Write-Host "Please create config.json with your values first." -ForegroundColor Yellow
    exit 1
}

# Read and validate configuration
Write-Host "`n[1/4] Validating configuration..." -ForegroundColor Cyan
$config = Get-Content $ConfigFile | ConvertFrom-Json

$requiredFields = @("subscription_id", "resource_group", "workspace_name", "location", "crowdstrike_api_base", "crowdstrike_client_id", "crowdstrike_client_secret")
$missingFields = @()

foreach ($field in $requiredFields) {
    $value = $config.$field
    if (-not $value -or $value -like "YOUR-*") {
        $missingFields += $field
    }
}

if ($missingFields.Count -gt 0) {
    Write-Host "ERROR: Please fill in these fields in config.json:" -ForegroundColor Red
    $missingFields | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    exit 1
}

Write-Host "  ✓ Configuration validated" -ForegroundColor Green
Write-Host "    Subscription: $($config.subscription_id)" -ForegroundColor Gray
Write-Host "    Resource Group: $($config.resource_group)" -ForegroundColor Gray
Write-Host "    Workspace: $($config.workspace_name)" -ForegroundColor Gray
Write-Host "    Location: $($config.location)" -ForegroundColor Gray

# Prompt for confirmation
Write-Host "`nThis will deploy:" -ForegroundColor Yellow
Write-Host "  • Data Collection Rule (DCR) with Direct ingestion" -ForegroundColor White
Write-Host "  • Connector Definition" -ForegroundColor White
Write-Host "  • 5 CrowdStrike Data Connectors" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: No DCE required - using DCR Direct kind" -ForegroundColor Cyan
Write-Host ""
$confirmation = Read-Host "Continue with deployment? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Phase 1: Deploy Infrastructure
Write-Host "[2/4] Deploying infrastructure (DCR only)..." -ForegroundColor Cyan
try {
    & .\deploy-infrastructure.ps1 -ConfigFile $ConfigFile
    if ($LASTEXITCODE -ne 0) {
        throw "Infrastructure deployment failed"
    }
    Write-Host "  ✓ Infrastructure deployed successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Infrastructure deployment failed: $_" -ForegroundColor Red
    Write-Host "`nDeployment stopped. Please fix errors and try again." -ForegroundColor Yellow
    exit 1
}

# Phase 2: Deploy Connector Definition
Write-Host "`n[3/4] Deploying connector definition..." -ForegroundColor Cyan
try {
    & .\deploy-definition.ps1 -ConfigFile "generated-config.json"
    if ($LASTEXITCODE -ne 0) {
        throw "Connector definition deployment failed"
    }
    Write-Host "  ✓ Connector definition deployed successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Connector definition deployment failed: $_" -ForegroundColor Red
    Write-Host "`nDeployment stopped. Infrastructure is deployed but connectors are not." -ForegroundColor Yellow
    exit 1
}

# Phase 3: Deploy All Connectors
Write-Host "`n[4/4] Deploying 5 data connectors..." -ForegroundColor Cyan
try {
    & .\deploy-all.ps1 -ConfigFile "generated-config.json"
    if ($LASTEXITCODE -ne 0) {
        throw "Connector deployment failed"
    }
}
catch {
    Write-Host "  ✗ Some connectors may have failed" -ForegroundColor Red
    Write-Host "`nCheck output above for details." -ForegroundColor Yellow
    exit 1
}

Write-Host @"

========================================
✓ Deployment Complete!
========================================

What was deployed:
  • Data Collection Rule (DCR) with Direct kind
  • Connector Definition
  • 5 Data Connectors (Vulnerabilities, Alerts, Incidents, Detections, Hosts)

Architecture:
  Connectors → DCR Direct Endpoint → Log Analytics Workspace
  (No DCE required - simplified deployment!)

Next steps:
1. Wait 30-45 minutes for initial data to start flowing
2. Subsequent polls will be faster (5-10 minutes)
3. Check Sentinel Log Analytics for data in these tables:
   - CrowdStrikeVulnerabilities
   - CrowdStrikeAlerts
   - CrowdStrikeIncidents
   - CrowdStrikeDetections
   - CrowdStrikeHosts

4. Run this KQL query in Sentinel to verify data ingestion:
   union CrowdStrike*
   | summarize Count=count() by Type
   | order by Count desc

Configuration saved in: generated-config.json
"@ -ForegroundColor Green
