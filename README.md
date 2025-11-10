# CrowdStrike Sentinel Connector - Setup Guide

This package connects CrowdStrike data to your Microsoft Sentinel workspace. Follow these 3 simple steps to get it working.

---

## Step 1: Fill in Your Information

Open the `config.json` file and replace the placeholder values with your real information:

```json
{
  "subscription_id": "YOUR_AZURE_SUBSCRIPTION_ID",
  "resource_group": "YOUR_RESOURCE_GROUP_NAME",
  "workspace_name": "YOUR_SENTINEL_WORKSPACE_NAME",
  "location": "YOUR_AZURE_REGION",
  "dce_name": "",
  "dcr_name": "",
  "crowdstrike_api_base": "https://api.crowdstrike.com",
  "crowdstrike_client_id": "YOUR_CROWDSTRIKE_CLIENT_ID",
  "crowdstrike_client_secret": "YOUR_CROWDSTRIKE_CLIENT_SECRET",
  "api_vulnerabilities_path": "/spotlight/combined/vulnerabilities/v1",
  "api_alerts_path": "/alerts/combined/alerts/v1",
  "api_incidents_path": "/incidents/queries/incidents/v1",
  "api_detections_path": "/detections/queries/detections/v1",
  "api_hosts_path": "/devices/queries/devices-scroll/v1"
}
```

**What you need to fill in:**

| Field | Description | Example |
|-------|-------------|---------|
| **subscription_id** | Your Azure subscription ID | `12345678-1234-1234-1234-123456789abc` |
| **resource_group** | Resource group with your Sentinel workspace | `my-sentinel-rg` |
| **workspace_name** | Your Sentinel workspace name | `my-sentinel-workspace` |
| **location** | Azure region | `eastus`, `westus`, `usgovvirginia` |
| **dce_name** | (Optional) Custom DCE name - leave empty for auto-generated unique name | `my-custom-dce` or `""` |
| **dcr_name** | (Optional) Custom DCR name - leave empty for auto-generated unique name | `my-custom-dcr` or `""` |
| **crowdstrike_api_base** | Your CrowdStrike API URL | `https://api.crowdstrike.com` (Commercial)<br>`https://api.us-2.crowdstrike.com` (GovCloud) |
| **crowdstrike_client_id** | Your CrowdStrike API client ID | `abc123def456...` |
| **crowdstrike_client_secret** | Your CrowdStrike API secret key | `xyz789uvw012...` |

**API Path Fields** (already set to correct values):
- **api_vulnerabilities_path** - CrowdStrike Vulnerabilities API endpoint
- **api_alerts_path** - CrowdStrike Alerts API endpoint
- **api_incidents_path** - CrowdStrike Incidents API endpoint  
- **api_detections_path** - CrowdStrike Detections API endpoint
- **api_hosts_path** - CrowdStrike Hosts/Devices API endpoint

> **Note:** The API path fields are pre-configured with the correct CrowdStrike API paths. Only change these if CrowdStrike updates their API endpoints.

**Save the file** after filling in your information.

---

## Step 2: Deploy!

Now deploy everything with one simple command:

```powershell
cd C:\path\to\your\download
.\deploy.ps1
```

Type **`yes`** when it asks you to confirm.

**What happens:**
1. ✓ Validates your configuration
2. ✓ Creates a Data Collection Endpoint (DCE)
3. ✓ Creates a Data Collection Rule (DCR)
4. ✓ Deploys the connector definition
5. ✓ Deploys 5 data connectors:
   - CrowdStrike Vulnerabilities
   - CrowdStrike Alerts
   - CrowdStrike Incidents
   - CrowdStrike Detections
   - CrowdStrike Hosts

The deployment takes about 2-3 minutes. A configuration file (`generated-config.json`) will be created automatically during deployment.

---

## Step 3: Verify Data is Flowing

**Initial startup:** Wait 30-45 minutes after first deployment for data to start appearing. Subsequent polling cycles will be faster (5-10 minutes).

Go to your Sentinel workspace and run this query:

```kql
union CrowdStrike*
| summarize Count=count() by Type
| order by Count desc
```

You should see data in these tables:
- `CrowdStrikeVulnerabilities`
- `CrowdStrikeAlerts`
- `CrowdStrikeIncidents`
- `CrowdStrikeDetections`
- `CrowdStrikeHosts`

---

## Clean Up (Optional)

If you need to remove everything and start fresh:

```powershell
.\cleanup.ps1
```

Type **`delete`** (or **`DELETE`**) when it asks you to confirm.

This will remove:
- All 5 data connectors
- The connector definition
- The Data Collection Rule (DCR)
- The Data Collection Endpoint (DCE)

The cleanup script verifies everything is actually deleted.

---

## File Reference

### Configuration Files

| File | Purpose | Do You Edit? |
|------|---------|--------------|
| **config.json** | Your Azure and CrowdStrike settings | ✅ YES - Fill this in before deployment |
| **generated-config.json** | Runtime configuration created during deployment | ❌ NO - Auto-generated (not in repo) |
| **.gitignore** | Prevents sensitive files from being committed to git | ❌ NO |

### Deployment Scripts

| File | What It Does | When To Run |
|------|--------------|-------------|
| **deploy.ps1** | Master deployment script - orchestrates entire deployment process | Run this to deploy everything |
| **deploy-infrastructure.ps1** | Creates DCE and DCR, generates `generated-config.json` | Called automatically by `deploy.ps1` |
| **deploy-definition.ps1** | Creates the CrowdStrike connector definition in Sentinel | Called automatically by `deploy.ps1` |
| **deploy-all.ps1** | Deploys all 5 data connectors (Vulnerabilities, Alerts, Incidents, Detections, Hosts) | Called automatically by `deploy.ps1` |
| **cleanup.ps1** | Deletes all deployed resources | Run when you want to remove everything |

### Connector Definition Files

These files define the configuration for each data connector. They contain template values that get populated from `config.json` during deployment.

| File | Connector Type | API Method | What It Collects |
|------|----------------|------------|------------------|
| **deploy-vulnerabilities.json** | CrowdStrike Vulnerabilities | GET | Software vulnerabilities detected by CrowdStrike |
| **deploy-alerts.json** | CrowdStrike Alerts | POST | Security alerts from CrowdStrike |
| **deploy-incidents.json** | CrowdStrike Incidents | GET | Security incidents tracked by CrowdStrike |
| **deploy-detections.json** | CrowdStrike Detections | POST | Threat detections from CrowdStrike |
| **deploy-hosts.json** | CrowdStrike Hosts | GET | Endpoint/device inventory from CrowdStrike |

> **Note:** These files contain placeholder values like `WILL_BE_POPULATED_AT_DEPLOYMENT`. During deployment, the scripts replace these with your actual values from `config.json`. After successful deployment, the files are updated with the real values for reference.

---

## How It Works

### Deployment Flow

```
deploy.ps1 (you run this)
    ↓
1. Validates config.json
    ↓
2. deploy-infrastructure.ps1
   - Creates DCE (Data Collection Endpoint)
   - Creates DCR (Data Collection Rule)
   - Generates generated-config.json with all runtime values
    ↓
3. deploy-definition.ps1
   - Creates connector definition in Sentinel
    ↓
4. deploy-all.ps1
   - Loads each deploy-*.json file
   - Replaces placeholders with values from config.json & generated-config.json
   - Deploys connector to Azure
   - Updates original deploy-*.json file with actual deployed values
    ↓
✓ Done! Connectors start polling within 30-45 minutes
```

### Data Collection Flow

```
CrowdStrike API
    ↓ (Connectors poll every 5 minutes)
Azure Sentinel Data Connectors
    ↓ (Send data via HTTPS)
Data Collection Endpoint (DCE)
    ↓ (Routes to correct destination)
Data Collection Rule (DCR)
    ↓ (Transforms and validates data)
Log Analytics Workspace
    ↓ (Indexes data into tables)
Microsoft Sentinel
    ↓ (Query with KQL)
Your Security Operations!
```

---

## Troubleshooting

### Deployment Failed?

**Check your configuration:**
```powershell
# Verify you're logged into Azure
az account show

# Check if you're using the correct subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify your Sentinel workspace exists
az monitor log-analytics workspace show --resource-group YOUR_RG --workspace-name YOUR_WORKSPACE
```

**Common issues:**
- ❌ Not logged into Azure → Run `az login`
- ❌ Wrong subscription selected → Run `az account set --subscription "YOUR_SUBSCRIPTION_ID"`
- ❌ Typo in config.json → Double-check all values
- ❌ Missing permissions → You need Contributor role on the resource group

### No Data Appearing?

**First deployment takes 30-45 minutes!** This is normal. Here's why:
1. Connectors need 5-10 minutes to initialize and start polling
2. CrowdStrike API responds with data
3. Data flows through DCE → DCR → Log Analytics (another 20-30 minutes)
4. Log Analytics indexes the data (5-10 minutes)

**After waiting 45+ minutes, still no data?**

Check connector status:
```powershell
az rest --method GET --url "https://management.azure.com/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RG/providers/Microsoft.OperationalInsights/workspaces/YOUR_WORKSPACE/providers/Microsoft.SecurityInsights/dataConnectors?api-version=2024-09-01" --query "value[].{Name:name, Active:properties.isActive}"
```

All connectors should show `"Active": true`.

**Other things to check:**
- ✓ CrowdStrike API credentials are correct
- ✓ CrowdStrike API client has required permissions (READ access to all APIs)
- ✓ CrowdStrike `api_base` URL is correct for your cloud (Commercial vs GovCloud)
- ✓ Network connectivity between Azure and CrowdStrike API

### Want to Redeploy?

```powershell
# 1. Clean up everything
.\cleanup.ps1

# 2. Wait for confirmation that all resources are deleted

# 3. Deploy fresh
.\deploy.ps1
```

### DCE/DCR Name Conflicts?

If you get an error about DCE or DCR already existing:

**Option 1: Use custom names** (recommended)
```json
{
  "dce_name": "my-unique-dce-name-v2",
  "dcr_name": "my-unique-dcr-name-v2"
}
```

**Option 2: Let the script auto-generate unique names**
```json
{
  "dce_name": "",
  "dcr_name": ""
}
```
Leave them as empty strings and the script will generate unique names like `dcr-crowdstrike-v2-endpoint-abcd`.

---

## GCC-High / Azure Government Cloud

If you're deploying to **Azure Government** (GCC-High):

**Update these values in config.json:**
```json
{
  "location": "usgovvirginia",
  "crowdstrike_api_base": "https://api.laggar.gcw.crowdstrike.com"
}
```

Everything else works the same!

---

## API Endpoint Reference

### CrowdStrike API Base URLs

| Environment | API Base URL |
|-------------|--------------|
| **US Commercial** | `https://api.crowdstrike.com` |
| **US Gov (GCC-High)** | `https://api.laggar.gcw.crowdstrike.com` |
| **EU** | `https://api.eu-1.crowdstrike.com` |
| **US-2** | `https://api.us-2.crowdstrike.com` |

### API Endpoints (Pre-configured in config.json)

These paths are appended to your `crowdstrike_api_base`:

| Connector | Path | Method |
|-----------|------|--------|
| Vulnerabilities | `/spotlight/combined/vulnerabilities/v1` | GET |
| Alerts | `/alerts/combined/alerts/v1` | POST |
| Incidents | `/incidents/queries/incidents/v1` | GET |
| Detections | `/detections/queries/detections/v1` | POST |
| Hosts | `/devices/queries/devices-scroll/v1` | GET |

> **Note:** The connector definitions automatically combine `crowdstrike_api_base` + `api_*_path` to build complete URLs.

---

## Need Help?

**Deployment questions?**
- Check the [Troubleshooting](#troubleshooting) section above
- Review the [File Reference](#file-reference) to understand what each script does
- Verify all values in `config.json` are correct

**CrowdStrike API issues?**
- Verify your API credentials in the CrowdStrike console
- Confirm your API client has READ permissions for all required APIs
- Check the [CrowdStrike API Documentation](https://falcon.crowdstrike.com/documentation/)

**Azure permissions issues?**
- You need **Contributor** role on the resource group
- You need **Microsoft Sentinel Contributor** role on the Sentinel workspace

---

## That's It!

**Two simple steps:**
1. ✏️ Fill in `config.json` with your Azure and CrowdStrike information
2. ▶️ Run `.\deploy.ps1`

Your CrowdStrike data will start flowing into Sentinel within 30-45 minutes!

**Questions?** Check the [File Reference](#file-reference) and [Troubleshooting](#troubleshooting) sections above.
