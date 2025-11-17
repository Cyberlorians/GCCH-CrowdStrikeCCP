#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CrowdStrike Connector - Prerequisites Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allGood = $true
$configPath = Join-Path -Path $PSScriptRoot -ChildPath 'config.json'

Write-Host "[1/5] Checking Azure CLI..." -ForegroundColor Cyan
try {
    $azVersion = az version --query "azure-cli" -o tsv 2>$null
    if ($azVersion) {
        Write-Host "  ✓ Azure CLI installed: $azVersion" -ForegroundColor Green
    } else {
        throw "Not found"
    }
} catch {
    Write-Host "  ✗ Azure CLI not found" -ForegroundColor Red
    Write-Host "    Install from: https://aka.ms/installazurecli" -ForegroundColor Yellow
    $allGood = $false
}

Write-Host "`n[2/5] Checking Azure authentication..." -ForegroundColor Cyan
try {
    $account = az account show 2>$null | ConvertFrom-Json
    if ($account) {
        Write-Host "  ✓ Logged in as: $($account.user.name)" -ForegroundColor Green
        Write-Host "    Subscription: $($account.name)" -ForegroundColor White
    } else {
        throw "Not logged in"
    }
} catch {
    Write-Host "  ✗ Not logged into Azure" -ForegroundColor Red
    Write-Host "    Run: az login" -ForegroundColor Yellow
    $allGood = $false
}

Write-Host "`n[3/5] Checking PowerShell version..." -ForegroundColor Cyan
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 5) {
    Write-Host "  ✓ PowerShell $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Green
} else {
    Write-Host "  ✗ PowerShell $($psVersion.Major).$($psVersion.Minor) - Need 5.1 or higher" -ForegroundColor Red
    $allGood = $false
}

Write-Host "`n[4/5] Checking config.json..." -ForegroundColor Cyan
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $requiredFields = @("subscription_id", "resource_group", "workspace_name", "location", "crowdstrike_api_base", "crowdstrike_client_id", "crowdstrike_client_secret")
        $missing = @()
        foreach ($field in $requiredFields) {
            if (-not $config.$field) {
                $missing += $field
            }
        }
        if ($missing.Count -eq 0) {
            Write-Host "  ✓ config.json is valid" -ForegroundColor Green
            Write-Host "    Subscription: $($config.subscription_id)" -ForegroundColor White
            Write-Host "    Resource Group: $($config.resource_group)" -ForegroundColor White
            Write-Host "    Workspace: $($config.workspace_name)" -ForegroundColor White
            Write-Host "    Location: $($config.location)" -ForegroundColor White
        } else {
            Write-Host "  ✗ config.json missing fields: $($missing -join ', ')" -ForegroundColor Red
            $allGood = $false
        }
    } catch {
        Write-Host "  ✗ config.json is invalid JSON" -ForegroundColor Red
        $allGood = $false
    }
} else {
    Write-Host "  ✗ config.json not found" -ForegroundColor Red
    Write-Host "    Copy and edit config.json with your Azure details" -ForegroundColor Yellow
    $allGood = $false
}

Write-Host "`n[5/5] Checking subscription access..." -ForegroundColor Cyan
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $currentAccount = az account show 2>$null | ConvertFrom-Json
        
        if ($currentAccount.id -eq $config.subscription_id) {
            Write-Host "  ✓ Using correct subscription" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ Warning: Logged into different subscription" -ForegroundColor Yellow
            Write-Host "    Current: $($currentAccount.id)" -ForegroundColor White
            Write-Host "    Config: $($config.subscription_id)" -ForegroundColor White
            Write-Host "    Run: az account set --subscription $($config.subscription_id)" -ForegroundColor Yellow
        }
        
        $rgExists = az group show --name $config.resource_group --subscription $config.subscription_id 2>$null
        if ($rgExists) {
            Write-Host "  ✓ Resource group '$($config.resource_group)' found" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Resource group '$($config.resource_group)' not found" -ForegroundColor Red
            $allGood = $false
        }
        
    } catch {
        Write-Host "  ✗ Could not verify subscription" -ForegroundColor Red
        $allGood = $false
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($allGood) {
    Write-Host "✓ All prerequisites met!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ready to deploy! Run:" -ForegroundColor White
    Write-Host "  .\deploy.ps1" -ForegroundColor Yellow
} else {
    Write-Host "✗ Prerequisites not met" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please fix the issues above before deploying." -ForegroundColor Yellow
}
Write-Host ""