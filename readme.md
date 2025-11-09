# CrowdStrike Sentinel Connector - Setup Guide

This package connects CrowdStrike data to your Microsoft Sentinel workspace. Follow these 3 simple steps to get it working.

---

## Step 1: Fill in Your Information

Open the `config.json` file and replace the placeholder values with your real information:

```json
{
  "subscription_id": "YOUR-SUBSCRIPTION-ID-HERE",
  "resource_group": "YOUR-RESOURCE-GROUP-NAME",
  "workspace_name": "YOUR-SENTINEL-WORKSPACE-NAME",
  "location": "eastus",
  "crowdstrike_api_base": "https://api.crowdstrike.com",
  "crowdstrike_client_id": "YOUR-CROWDSTRIKE-CLIENT-ID",
  "crowdstrike_client_secret": "YOUR-CROWDSTRIKE-CLIENT-SECRET"
}
```

**What you need:**
- **subscription_id**: Your Azure subscription ID (found in Azure Portal)
- **resource_group**: The resource group where your Sentinel workspace lives
- **workspace_name**: Your Sentinel workspace name
- **location**: Azure region (examples: `eastus`, `westus`, `usgovvirginia`)
- **crowdstrike_api_base**: Your CrowdStrike API URL
- **crowdstrike_client_id**: Your CrowdStrike API client ID
- **crowdstrike_client_secret**: Your CrowdStrike API secret key

**Save the file** after filling in your information.

---

## Step 2: Check Everything is Ready

Before deploying, let's make sure your environment is ready.

Open PowerShell and run:

```powershell
cd C:\path\to\customer-package
.\prereq-check.ps1
```

This script checks:
- ✓ You're logged into Azure
- ✓ You're using the correct subscription
- ✓ Your Sentinel workspace exists
- ✓ You have the right permissions
- ✓ Required Azure providers are registered

**If everything passes**, you're ready for Step 3!

**If something fails**, the script will tell you what's wrong and how to fix it.

---

## Step 3: Deploy!

Now let's deploy everything with one simple command:

```powershell
.\deploy.ps1
```

Type **`yes`** when it asks you to confirm.

**What happens:**
1. Creates a Data Collection Endpoint (DCE)
2. Creates a Data Collection Rule (DCR)
3. Deploys the connector definition
4. Deploys 5 data connectors:
   - Vulnerabilities
   - Alerts
   - Incidents
   - Detections
   - Hosts

The deployment takes about 2-3 minutes.

---

## Verify Data is Flowing

After deployment, wait 5-10 minutes for data to start appearing.

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

## Need Help?

**Deployment failed?**
- Re-run `.\prereq-check.ps1` to see what's wrong
- Check that all values in `config.json` are correct
- Make sure you're logged into the right Azure subscription

**No data appearing?**
- Wait at least 10 minutes after deployment
- Check CrowdStrike API credentials are correct
- Verify your CrowdStrike API has the right permissions

**Want to redeploy?**
1. Run `.\cleanup.ps1` to delete everything
2. Run `.\deploy.ps1` to deploy fresh

---

## File Overview

You don't need to touch these files, but here's what they do:

- **config.json** - Your settings (you edit this)
- **deploy.ps1** - Main deployment script (runs everything)
- **cleanup.ps1** - Deletes all resources
- **prereq-check.ps1** - Checks if you're ready to deploy

Everything else is used automatically during deployment.

---

## That's It!

**Three simple steps:**
1. Fill in `config.json`
2. Run `.\prereq-check.ps1`
3. Run `.\deploy.ps1`

Your CrowdStrike data will start flowing into Sentinel!
