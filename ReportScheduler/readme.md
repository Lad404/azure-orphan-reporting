# TimerTrigger - PowerShell

The `TimerTrigger` makes it incredibly easy to have your functions executed on a schedule. This sample demonstrates a simple use case of calling your function every 5 minutes.

## How it works

For a `TimerTrigger` to work, you provide a schedule in the form of a [cron expression](https://en.wikipedia.org/wiki/Cron#CRON_expression)(See the link for full details). A cron expression is a string with 6 separate expressions which represent a given schedule via patterns. The pattern we use to represent every 5 minutes is `0 */5 * * * *`. This, in plain text, means: "When seconds is equal to 0, minutes is divisible by 5, for any hour, day of the month, month, and day of the week".

## Learn more

<TODO> Documentation


# Azure Orphan Resource Reporting Automation

## Overview

This project automates Azure orphan resource reporting using:

- Azure Functions (PowerShell)
- Azure Resource Graph (ARG)
- Managed Identity
- Azure Blob Storage
- Microsoft Graph API (optional for email)
- KQL orphan resource queries

The solution runs on a scheduled Azure Function and generates orphan resource reports in CSV format, uploads them to Azure Blob Storage, and optionally sends them via email.

---

# Architecture

```text
Azure Function (PowerShell Timer Trigger)
        │
        ├── Managed Identity Authentication
        │
        ├── Execute ARG KQL Queries
        │
        ├── Generate CSV Report
        │
        ├── Upload Report to Blob Storage
        │
        └── Send Email via Graph API (Optional)
```

---

# Features

- Automated orphan resource discovery
- Centralized KQL query execution
- Blob storage archival
- Timestamped reports
- Managed Identity authentication
- No secrets stored in code
- Production-safe temp storage usage
- Query failure isolation
- Detailed logging

---

# Folder Structure

```text
Azure-Orphan-Reporting/
│
├── host.json
├── requirements.psd1
├── .gitignore
│
├── ReportScheduler/
│   ├── function.json
│   └── run.ps1
│
├── queries/
│   ├── orphan-NSGs.kql
│   ├── orphan-Vnets.kql
│   ├── orphan-RouteTables.kql
│   └── ...
```

---

# Azure Resources Used

| Resource | Purpose |
|---|---|
| Azure Function App | Automation runtime |
| Storage Account | Blob report storage |
| Managed Identity | Authentication |
| Azure Resource Graph | Query orphan resources |
| Application Insights | Monitoring and logs |
| Microsoft Graph API | Email notifications |

---

# Required RBAC Permissions

## Function App Managed Identity

Assign these roles:

| Role | Scope |
|---|---|
| Reader | Subscription |
| Resource Graph Reader | Subscription |
| Storage Blob Data Contributor | Storage Account |

---

# Function App Settings

Configure these under:

```text
Function App → Environment Variables
```

| Name | Example |
|---|---|
| STORAGE_ACCOUNT_NAME | stgreportautomation01 |
| BLOB_CONTAINER_NAME | reports |
| MAIL_SENDER | alerts@company.com |
| MAIL_RECIPIENT | client@company.com |

---

# PowerShell Dependencies

`requirements.psd1`

```powershell
@{
    'Az.Accounts'      = '4.*'
    'Az.ResourceGraph' = '1.*'
    'Az.Storage'       = '8.*'
}
```

---

# Scheduling

Current schedule:

```text
Every Saturday
```

Production recommendation:

```text
2nd and 4th Saturday
```

Cron example:

```json
"schedule": "0 0 10 * * 6"
```

---

# Blob Storage Structure

Reports are uploaded as:

```text
reports/yyyy/MM/orphan-report-<timestamp>.csv
```

Example:

```text
reports/2026/05/orphan-report-20260513-134500.csv
```

---

# Logging

Logs are available in:

```text
Function App
→ Monitor
```

OR

```text
Application Insights
→ Logs
```

---

# Common Issues Faced During Implementation

## 1. Azure Function Timeout

### Problem

ARI + orphan reporting together exceeded Consumption Plan timeout.

Error:

```text
Timeout value of 00:05:00 exceeded
```

### Fix

Separated ARI into a future standalone implementation.

Current Function handles only orphan reporting.

---

## 2. Azure Resource Graph Pagination Issue

### Problem

Used:

```powershell
-First 5000
```

ARG supports maximum:

```text
1000
```

### Fix

Reduced query batch size to:

```powershell
-First 1000
```

---

## 3. `-Skip 0` Failure in ARG

### Problem

Used:

```powershell
-Skip 0
```

ARG rejected it.

### Fix

Removed unnecessary pagination logic.

---

## 4. Path Issues in Azure Functions

### Problem

Azure Functions intermittently used:

```text
C:\local\Temp\functions\standby\wwwroot
```

instead of:

```text
C:\home\site\wwwroot
```

### Fix

Used:

```powershell
$PSScriptRoot
```

for dynamic paths.

---

## 5. Output File Write Failures

### Problem

CSV export failed inside:

```text
wwwroot
```

### Fix

Used:

```powershell
$env:TEMP
```

for runtime-generated files.

---

## 6. Blob Upload Authorization Failure

### Problem

Received:

```text
403 AuthorizationPermissionMismatch
```

### Fix

Assigned:

```text
Storage Blob Data Contributor
```

to Function Managed Identity.

---

## 7. Duplicate Blob Uploads

### Problem

Multiple executions attempted uploading same blob.

Error:

```text
A transfer operation with the same source and destination already exists
```

### Fix

Implemented timestamp-based filenames.

---

## 8. Graph API Mail Permission Issues

### Problem

Received:

```text
403 ErrorAccessDenied
```

because admin consent was restricted by organization policies.

### Current Status

Blob upload works successfully.

Email sending pending organizational approval.

---

## 9. Empty or Invalid KQL Handling

### Problem

Single bad query failed entire execution.

### Fix

Implemented:
- query isolation
- try/catch per query
- skip invalid queries

---

# Security Best Practices

- No secrets stored in code
- Managed Identity authentication used
- Blob uploads via RBAC
- Environment variables used for configuration
- Git ignored sensitive files

---

# Future Improvements

## Planned ARI Architecture

ARI will be implemented separately using:

- Azure Function Premium Plan
OR
- Azure Container Apps

because ARI is resource-intensive.

---

# Git Ignore

`.gitignore`

```gitignore
bin/
obj/
.vscode/
local.settings.json
outputs/
*.user
```

---

# Deployment

## Publish Function

```powershell
func azure functionapp publish <function-app-name>
```

---

# Useful References

## Azure Orphan Resources

https://github.com/dolevshor/azure-orphan-resources

## Azure Resource Inventory (ARI)

https://github.com/microsoft/ARI

## Azure Functions PowerShell

https://learn.microsoft.com/azure/azure-functions/functions-reference-powershell

---

# Current Status

| Component | Status |
|---|---|
| Managed Identity | ✅ |
| ARG Queries | ✅ |
| CSV Generation | ✅ |
| Blob Upload | ✅ |
| Timestamped Reports | ✅ |
| Query Isolation | ✅ |
| Email Sending | Admin consent restricted due to org policies|
| ARI Integration | Planned Separately |

---

# Author

Sumit Lad

---
