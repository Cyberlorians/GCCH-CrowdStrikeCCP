# CrowdStrike Sentinel Connector - Setup Guide

This package connects CrowdStrike data to your Microsoft Sentinel workspace using **Direct DCR ingestion (no DCE required)**. Follow these 3 simple steps to get it working.

---


---

## Prerequisites

Before you begin, **run the prerequisites check script**:

```powershell
.\prereq-check.ps1
```

This automated script verifies:
- ✅ Azure CLI is installed
- ✅ You're logged into Azure (Government or Commercial)
- ✅ PowerShell version 5.1+
- ✅ `config.json` is filled in correctly
- ✅ Subscription and resource group access

### Manual Prerequisites (if not automated)

If you need to set things up manually:

**1. Install Azure CLI**
```powershell
# Download from: https://aka.ms/installazurecliwindows
az --version  # Verify installation
```

**2. Connect to Azure Government (GCC-High)**
```powershell
az cloud set --name AzureUSGovernment
az login
az cloud show --query name  # Should return: "AzureUSGovernment"
```

**For Commercial Azure:**
```powershell
az cloud set --name AzureCloud
az login
```

**3. Get CrowdStrike API Credentials**

From CrowdStrike Falcon Console → Support → API Clients & Keys

Required permissions:
- Spotlight Vulnerabilities: **Read**
- Alerts: **Read**
- Incidents: **Read**
- Detections: **Read**
- Hosts/Devices: **Read**

---
## Step 1: Fill in Your Information

Open the `config.json` file and replace the placeholder values with your real information:

```json
{
  "subscription_id": "YOUR_AZURE_SUBSCRIPTION_ID",
  "resource_group": "YOUR_RESOURCE_GROUP_NAME",
  "workspace_name": "YOUR_SENTINEL_WORKSPACE_NAME",
  "location": "YOUR_AZURE_REGION",
  "dcr_name": "",
  "crowdstrike_api_base": "https://api.laggar.gcw.crowdstrike.com",
  "crowdstrike_client_id": "YOUR_CROWDSTRIKE_CLIENT_ID",
  "crowdstrike_client_secret": "YOUR_CROWDSTRIKE_CLIENT_SECRET",
  "api_vulnerabilities_path": "/spotlight/combined/vulnerabilities/v1",
  "api_alerts_path": "/alerts/entities/alerts/v1",
  "api_incidents_path": "/incidents/queries/incidents/v1",
  "api_detections_path": "/detects/entities/summaries/GET/v1",
  "api_hosts_path": "/devices/entities/devices/v1"
}
```

**What you need to fill in:**

| Field | Description | Example |
|-------|-------------|---------|
| **subscription_id** | Your Azure subscription ID | `12345678-1234-1234-1234-123456789abc` |
| **resource_group** | Resource group with your Sentinel workspace | `my-sentinel-rg` |
| **workspace_name** | Your Sentinel workspace name | `my-sentinel-workspace` |
| **location** | Azure region | `usgovvirginia` (GCC-High) |
| **dcr_name** | (Optional) Custom DCR name - leave empty for auto-generated unique name | `my-custom-dcr` or `""` |
| **crowdstrike_api_base** | Your CrowdStrike API URL | `https://api.laggar.gcw.crowdstrike.com` (GCC-High)<br>`https://api.crowdstrike.com` (Commercial) |
| **crowdstrike_client_id** | Your CrowdStrike API client ID | `abc123def456...` |
| **crowdstrike_client_secret** | Your CrowdStrike API secret key | `xyz789uvw012...` |

**API Path Fields** (pre-configured with correct CrowdStrike endpoints):
- **api_vulnerabilities_path** - `/spotlight/combined/vulnerabilities/v1`
- **api_alerts_path** - `/alerts/entities/alerts/v1`
- **api_incidents_path** - `/incidents/queries/incidents/v1`
- **api_detections_path** - `/detects/entities/summaries/GET/v1`
- **api_hosts_path** - `/devices/entities/devices/v1`

> **Note:** API paths are pre-configured and should not need modification unless CrowdStrike changes their API.

---

## Step 2: Run the Deployment

Open PowerShell in this directory and run:

```powershell
.\deploy.ps1
```

This single script will:
1. **Create the Data Collection Rule (DCR)** with Direct ingestion
2. **Deploy the connector definition**
3. **Deploy all 5 data connectors**

The deployment takes about 2-3 minutes.

---

## Step 3: Wait for Data

After deployment:
- **Initial data:** 30-45 minutes (Sentinel backend scheduling)
- **Subsequent polls:** Every 5 minutes

Check for data in Sentinel Log Analytics:
- `CrowdStrikeVulnerabilities`
- `CrowdStrikeAlerts`
- `CrowdStrikeIncidents`
- `CrowdStrikeDetections`
- `CrowdStrikeHosts`

**Verify data ingestion:**
```kql
union CrowdStrike*
| where TimeGenerated > ago(10m)
| summarize Count=count() by Type
| order by Count desc
```

---

## Architecture

**Simplified Direct Ingestion (No DCE Required):**

```
CrowdStrike API → Connectors (5) → DCR Direct Endpoint → Log Analytics Workspace
```

**What gets deployed:**
- ✅ **1 Data Collection Rule (DCR)** with Direct kind (generates its own ingestion endpoint)
- ✅ **1 Connector Definition** (template for all connectors)
- ✅ **5 Data Connectors** (Vulnerabilities, Alerts, Incidents, Detections, Hosts)

**No Data Collection Endpoint (DCE) required!** The DCR with `kind: "Direct"` automatically generates its own logs ingestion endpoint.

---

## Data Collected

| Connector | CrowdStrike API | Sentinel Table | Polling Interval |
|-----------|----------------|----------------|------------------|
| **Vulnerabilities** | Spotlight Vulnerabilities | `CrowdStrikeVulnerabilities` | 5 minutes |
| **Alerts** | Alerts | `CrowdStrikeAlerts` | 5 minutes |
| **Incidents** | Incidents | `CrowdStrikeIncidents` | 7 minutes |
| **Detections** | Detections | `CrowdStrikeDetections` | 6 minutes |
| **Hosts** | Devices | `CrowdStrikeHosts` | 5 minutes |

---

## Cleanup

To remove all deployed resources:

```powershell
.\cleanup.ps1
```

This will delete:
- All 5 data connectors
- Connector definition
- Data Collection Rule (DCR)

**Note:** Historical data in Sentinel tables will remain.

---

## Troubleshooting

### No data after 45 minutes

1. **Check connector status:**
   ```powershell
   # In Azure Portal: Sentinel → Data Connectors → Search "CrowdStrike"
   # Should show "Connected" status
   ```

2. **Verify CrowdStrike credentials:**
   - Test credentials using CrowdStrike API directly
   - Ensure API client has correct permissions

3. **Check DCR logs endpoint:**
   - Review `generated-config.json` for `dcr_logs_endpoint`
   - Should be `https://<dcrname>-<suffix>-<region>.logs.z1.ingest.monitor.azure.us`

### Deployment fails

- **Azure permissions:** Ensure you have Contributor or Owner role on the resource group
- **Sentinel workspace:** Verify workspace exists and is accessible
- **Azure Government:** If using GCC-High, ensure `location` is a Gov region (e.g., `usgovvirginia`)

### API rate limiting

- Connectors use `rateLimitQPS: 10` (10 queries per second)
- If you hit CrowdStrike rate limits, reduce this value in `CrowdStrikeAPI_PollingConfig.json`

---

## Files in This Package

| File | Purpose |
|------|---------|
| **config.json** | Customer configuration (fill this in first!) |
| **deploy.ps1** | Master deployment script (runs all steps) |
| **deploy-infrastructure.ps1** | Creates DCR with Direct kind |
| **deploy-definition.ps1** | Deploys connector definition |
| **deploy-all.ps1** | Deploys all 5 data connectors |
| **cleanup.ps1** | Removes all deployed resources |
| **CrowdStrikeAPI_DCR.json** | DCR template |
| **CrowdStrikeAPI_Definition.json** | Connector definition template |
| **CrowdStrikeAPI_PollingConfig.json** | Polling configuration for all 5 connectors |
| **deploy-*.json** | Individual connector templates (5 files) |

---

## Support

For issues or questions:
1. Check `generated-config.json` for deployed resource IDs
2. Review Azure Portal → Sentinel → Data Connectors for connector status
3. Check connector logs in Azure Monitor

---

## What's Different: No DCE Architecture

**Traditional approach:**
```
Connectors → Data Collection Endpoint (DCE) → Data Collection Rule (DCR) → Log Analytics
```

**This deployment (simplified):**
```
Connectors → Data Collection Rule (DCR with Direct kind) → Log Analytics
```

**Benefits:**
- ✅ One less Azure resource to manage
- ✅ Simpler deployment (fewer steps)
- ✅ Easier troubleshooting (fewer components)
- ✅ Same functionality and performance
- ✅ Slightly lower Azure costs

The DCR's built-in `logsIngestion` endpoint (generated when using `kind: "Direct"`) handles data ingestion directly, eliminating the need for a separate DCE resource.
