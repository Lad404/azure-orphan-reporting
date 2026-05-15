# TimerTrigger - PowerShell

The `TimerTrigger` makes it incredibly easy to have your functions executed on a schedule. This sample demonstrates a simple use case of calling your function every 5 minutes.

## How it works

For a `TimerTrigger` to work, you provide a schedule in the form of a [cron expression](https://en.wikipedia.org/wiki/Cron#CRON_expression)(See the link for full details). A cron expression is a string with 6 separate expressions which represent a given schedule via patterns. The pattern we use to represent every 5 minutes is `0 */5 * * * *`. This, in plain text, means: "When seconds is equal to 0, minutes is divisible by 5, for any hour, day of the month, month, and day of the week".

## Learn more

<TODO> Documentation


# Azure Orphan Resource Reporting Automation

## Overview

This project automates Azure orphan resource reporting using:

* Azure Functions (PowerShell)
* Azure Resource Graph (ARG)
* Managed Identity
* Azure Blob Storage
* Microsoft Graph API
* KQL orphan resource queries

The solution runs automatically on a scheduled Azure Function, executes orphan resource queries using Azure Resource Graph, generates clean CSV reports, uploads them to Azure Blob Storage, and sends the reports via email automatically.

This implementation was designed to eliminate manual orphan resource tracking and improve Azure governance visibility.

---

# Architecture

```text
Azure Function (PowerShell Timer Trigger)
        │
        ├── Managed Identity Authentication
        │
        ├── Read KQL Query Files
        │
        ├── Execute ARG Queries
        │
        ├── Transform Raw ARG Output
        │
        ├── Generate Clean CSV Report
        │
        ├── Upload Report to Blob Storage
        │
        └── Send Email via Microsoft Graph API
```

---

# Features

* Automated orphan resource discovery
* Centralized KQL query execution
* Clean enterprise-grade CSV formatting
* Subscription name mapping
* Resource type extraction
* Tag formatting
* Blob storage archival
* TO and CC email support
* Managed Identity authentication
* Microsoft Graph email integration
* Production-safe temp storage usage
* Query failure isolation
* Detailed logging

---

# What are Orphan Resources?

Orphan resources are Azure resources that:

* are unused
* are disconnected
* are not attached to workloads
* increase cloud cost unnecessarily
* create governance and security risks

Examples:

* Unused NSGs
* Empty Resource Groups
* Unused Route Tables
* Orphan VNets
* Unused Public IPs

---

# Folder Structure

```text
AzureReporting/
│
├── .vscode/
│
├── queries/
│   ├── orphan-NSGs.kql
│   ├── orphan-Vnets.kql
│   ├── orphan-routetables.kql
│   └── ...
│
├── ReportScheduler/
│   ├── function.json
│   ├── readme.md
│   └── run.ps1
│
├── host.json
├── requirements.psd1
├── local.settings.json
├── profile.ps1
├── .gitignore
└── README.md
```

---

# Azure Resources Used

| Resource             | Purpose                |
| -------------------- | ---------------------- |
| Azure Function App   | Automation runtime     |
| Storage Account      | Blob report storage    |
| Managed Identity     | Authentication         |
| Azure Resource Graph | Query orphan resources |
| Application Insights | Monitoring and logs    |
| Microsoft Graph API  | Email notifications    |

---

# Step-by-Step Implementation

---

# STEP 1 — Create Storage Account

## Why?

Storage Account is required for:

* Azure Function runtime
* Blob report archival

---

## Actions Performed

Created:

* Azure Storage Account

Created Blob Container:

```text
reports
```

Purpose:

* stores generated orphan reports

---

# STEP 2 — Create Azure Function App

## Why?

Azure Function provides:

* serverless execution
* automatic scheduling
* PowerShell support
* low operational overhead

---

## Configuration Used

| Setting | Value            |
| ------- | ---------------- |
| Runtime | PowerShell       |
| OS      | Windows          |
| Hosting | Consumption Plan |

---

# STEP 3 — Enable Managed Identity

## Why?

Managed Identity allows secure authentication without:

* hardcoded credentials
* stored passwords
* secrets in code

---

## Portal Path

```text
Function App
→ Identity
→ System Assigned
→ Enable
```

---

# STEP 4 — Assign RBAC Permissions

## Why?

Function requires permissions to:

* read Azure resources
* upload reports to Blob Storage

---

## Roles Assigned

| Role                          | Scope           |
| ----------------------------- | --------------- |
| Reader                        | Subscription    |
| Storage Blob Data Contributor | Storage Account |

---

# STEP 5 — Download Orphan Resource Queries

## Query Source

Queries were taken from:

[Azure Orphan Resources GitHub Repository](https://github.com/dolevshor/azure-orphan-resources?utm_source=chatgpt.com)

---

## Why This Repository?

This repository provides:

* production-ready orphan resource KQL queries
* validated Azure governance logic
* community-maintained orphan detection queries

---

## Actions Performed

Downloaded required `.kql` query files and stored them in:

```text
queries/
```

folder.

---

# STEP 6 — Create Timer Trigger Function

## Why?

Timer Trigger enables:

* scheduled execution
* fully automated reporting
* no manual intervention

---

# Initial Testing Schedule

During testing, the function was configured to run every 5 minutes.

## Cron Used

```json
"schedule": "0 */5 * * * *"
```

---

# Why Every 5 Minutes?

This allowed:

* rapid validation
* faster debugging
* end-to-end testing
* immediate email verification

without waiting for weekly schedules.

---

# Production Schedule

Production schedule:

```json
"schedule": "0 0 10 * * 6"
```

Meaning:

```text
Every Saturday at 10 AM UTC
```

---

# STEP 7 — Implement 2nd and 4th Saturday Logic

## Problem

Azure Function CRON scheduling cannot reliably represent:

```text
2nd and 4th Saturday
```

---

## Solution

Implemented scheduling validation directly inside:

```text
run.ps1
```

The script:

* runs every Saturday
* checks current week number
* exits unless:

  * 2nd Saturday
  * 4th Saturday

---

## Benefit

Provides:

* reliable scheduling
* easier maintenance
* enterprise-friendly scheduling logic

---

# STEP 8 — Implement PowerShell Automation Logic

## Main Script

```text
ReportScheduler/run.ps1
```

---

# What the Script Does

The script performs:

1. Azure login using Managed Identity
2. Reads all `.kql` files
3. Executes Azure Resource Graph queries
4. Collects orphan resources
5. Cleans raw ARG output
6. Generates clean CSV report
7. Uploads report to Blob Storage
8. Sends email using Microsoft Graph API

---

# STEP 9 — Configure Microsoft Graph API

## Why?

Microsoft Graph API is used for:

* secure enterprise email delivery
* App Registration authentication
* automation-friendly mail sending

---

# App Registration Creation

Portal Path:

```text
Microsoft Entra ID
→ App Registrations
→ New Registration
```

---

# STEP 10 — Configure Graph API Permissions

## Initial Problem Faced

Email sending initially failed with:

```text
403 Forbidden
ErrorAccessDenied
```

---

## Root Cause

Configured:

```text
Delegated Permissions
```

instead of:

```text
Application Permissions
```

---

## Final Correct Permission

| Permission | Type        |
| ---------- | ----------- |
| Mail.Send  | Application |

---

## Important Step

Admin consent was granted after adding permissions.

---

# STEP 11 — Configure Function App Environment Variables

## Why?

To avoid:

* hardcoded credentials
* secrets inside code

---

# Variables Configured

| Variable      | Purpose                    |
| ------------- | -------------------------- |
| TENANT_ID     | Azure Tenant ID            |
| CLIENT_ID     | App Registration Client ID |
| CLIENT_SECRET | App Registration Secret    |
| SENDER_EMAIL  | Sender mailbox             |
| TO_RECIPIENTS | TO recipients              |
| CC_RECIPIENTS | CC recipients              |

---

# STEP 12 — Implement Clean CSV Formatting

## Initial Problem

Raw Azure Resource Graph output contained:

* ARM payloads
* JSON blobs
* unreadable Details column

---

## Solution Implemented

Added:

* subscription name mapping
* resource type extraction
* clean tag formatting
* simplified operational columns

---

# Final CSV Format

| Column        | Description         |
| ------------- | ------------------- |
| Subscription  | Subscription Name   |
| ResourceName  | Resource Name       |
| ResourceType  | Azure Resource Type |
| ResourceGroup | Resource Group      |
| Location      | Azure Region        |
| Tags          | Resource Tags       |

---

# STEP 13 — Configure Blob Upload

## Why?

Blob Storage provides:

* centralized archival
* historical reporting
* easy retrieval
* low-cost storage

---

# Blob Structure Used

```text
reports/yyyy/MM/orphan-report-<timestamp>.csv
```

Example:

```text
reports/2026/05/orphan-report-20260515.csv
```

---

# STEP 14 — Implement Email Notification

## Email Subject

```text
Azure Orphan Resource Report
```

---

# Email Body

```text
Hello Team,

PFA updated orphan resources report.

Regards,
Synergetics Cloud Team
```

---

# STEP 15 — Test Full Automation

## Manual Testing Performed

Initially validated:

* Function execution
* ARG query execution
* Blob upload
* email delivery

using:

```text
Test/Run
```

inside Azure Functions.

---

# Automated Testing Performed

Then validated actual automation using:

```text
every 5 minute schedule
```

This validated:

* timer execution
* automatic email sending
* automatic blob uploads
* automatic report generation

without manual triggering.

---

# Logs Validation

Logs verified from:

```text
Function App
→ Monitor
```

and:

```text
Application Insights
→ Logs
```

---

# Common Issues Faced During Implementation

---

# 1. Azure Function Timeout

## Problem

ARI + orphan reporting together exceeded Consumption Plan timeout.

---

## Resolution

Separated ARI implementation from orphan reporting automation.

ARI planned as future standalone implementation.

---

# 2. Azure Resource Graph Pagination Issue

## Problem

Used:

```powershell
-First 5000
```

ARG supports maximum:

```text
1000
```

---

## Resolution

Reduced query batch size to:

```powershell
-First 1000
```

---

# 3. `-Skip 0` Failure in ARG

## Problem

Azure Resource Graph rejected:

```powershell
-Skip 0
```

---

## Resolution

Removed unnecessary pagination logic.

---

# 4. Path Issues in Azure Functions

## Problem

Azure Functions intermittently used:

```text
C:\local\Temp\functions\standby\wwwroot
```

instead of:

```text
C:\home\site\wwwroot
```

---

## Resolution

Implemented dynamic paths using:

```powershell
$PSScriptRoot
```

---

# 5. CSV Write Failures

## Problem

CSV generation failed inside:

```text
wwwroot
```

---

## Resolution

Used:

```powershell
$env:TEMP
```

for runtime-generated files.

---

# 6. Blob Upload Authorization Failure

## Problem

Received:

```text
403 AuthorizationPermissionMismatch
```

---

## Resolution

Assigned:

```text
Storage Blob Data Contributor
```

to Function Managed Identity.

---

# 7. Duplicate Blob Uploads

## Problem

Multiple executions attempted uploading same blob.

---

## Resolution

Implemented timestamp-based filenames.

---

# 8. Graph API Mail Permission Issues

## Problem

Received:

```text
403 ErrorAccessDenied
```

---

## Root Cause

Configured Delegated permissions instead of Application permissions.

---

## Resolution

Configured:

* Mail.Send (Application)
* Admin Consent

---

# 9. Empty Resource Group and Tags

## Problem

CSV showed blank:

* Resource Group
* Tags

---

## Root Cause

Incorrect PowerShell property mappings.

---

## Resolution

Updated mappings:

* `resourceGroup`
* `tags`

---

# 10. Subscription IDs Instead of Names

## Problem

CSV showed subscription GUIDs.

---

## Resolution

Implemented subscription lookup using:

```powershell
Get-AzSubscription
```

---

# Security Best Practices

* Managed Identity authentication
* No hardcoded secrets
* Environment variable configuration
* RBAC-based access
* Least privilege model
* Microsoft Graph Application permissions

---

# Future Improvements

## Planned Enhancements

### 1. Excel Report Generation

Generate:

* formatted XLSX
* filters
* conditional formatting
* auto-sized columns

using:

```text
ImportExcel
```

---

### 2. HTML Email Summary

Embed orphan resource summary directly in email body.

---

### 3. Cost Estimation

Estimate monthly cost impact of orphan resources.

---

### 4. Severity Classification

Classify resources:

* High
* Medium
* Low

based on:

* exposure
* networking
* cost impact

---

### 5. ITSM Integrations

Future integrations:

* Microsoft Teams
* ServiceNow
* Jira

---

# Current Status

| Component                | Status |
| ------------------------ | ------ |
| Managed Identity         | ✅      |
| ARG Queries              | ✅      |
| CSV Generation           | ✅      |
| Blob Upload              | ✅      |
| Graph Authentication     | ✅      |
| Email Delivery           | ✅      |
| TO/CC Recipients         | ✅      |
| Automated Scheduling     | ✅      |
| 2nd & 4th Saturday Logic | ✅      |
| Clean CSV Formatting     | ✅      |

---

# Useful References

## Azure Orphan Resources

[Azure Orphan Resources GitHub Repository](https://github.com/dolevshor/azure-orphan-resources?utm_source=chatgpt.com)

## Azure Resource Graph

[Azure Resource Graph Documentation](https://learn.microsoft.com/en-us/azure/governance/resource-graph/overview?utm_source=chatgpt.com)

## Microsoft Graph API

[Microsoft Graph API Documentation](https://learn.microsoft.com/en-us/graph/overview?utm_source=chatgpt.com)

## Azure Functions PowerShell

[Azure Functions PowerShell Guide](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-powershell?utm_source=chatgpt.com)

---

# Author

Sumit Lad

Cloud & Azure Automation Engineering
