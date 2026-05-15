param($Timer)

# ================================
# CONFIGURATION
# ================================

$storageAccountName = "stgreportautomation01"
$blobContainerName  = "reports"

# =========================================
# MAIL CONFIGURATION
# =========================================

$mailSender = $env:SENDER_EMAIL

$toRecipientsRaw = $env:TO_RECIPIENTS

$ccRecipientsRaw = $env:CC_RECIPIENTS

# App Registration Details

$tenantId = $env:TENANT_ID

$clientId = $env:CLIENT_ID

$clientSecret = $env:CLIENT_SECRET
# ================================
# LOG START
# ================================

Write-Output "========================================"
Write-Output "Azure Orphan Reporting Started"
Write-Output "Time: $(Get-Date)"
Write-Output "========================================"

# ================================
# LOGIN USING MANAGED IDENTITY
# ================================

try {

    Write-Output "Connecting to Azure using Managed Identity..."

    Connect-AzAccount -Identity -ErrorAction Stop

    Write-Output "Azure login successful"

# =========================================
# RUN ONLY ON 2ND AND 4TH SATURDAY
# =========================================

$today = Get-Date

$weekNumber = [math]::Ceiling($today.Day / 7)

Write-Output "Today: $($today.DayOfWeek)"
Write-Output "Week Number: $weekNumber"

if (
    $today.DayOfWeek -ne "Saturday" -or
    ($weekNumber -ne 2 -and $weekNumber -ne 4)
) {

    Write-Output "Not 2nd or 4th Saturday. Exiting."

    return
}

Write-Output "Valid execution window detected. Continuing..."

}
catch {

    Write-Error "Azure login failed"

    Write-Error $_.Exception.Message

    throw
}

# ================================
# DYNAMIC PATH CONFIGURATION
# ================================

try {

    Write-Output "========================================"
    Write-Output "Setting dynamic paths"
    Write-Output "========================================"

    $rootPath = Split-Path $PSScriptRoot -Parent

    $queryPath = Join-Path $rootPath "queries"

    # TEMP writable path

    $outputPath = Join-Path $env:TEMP "outputs"

    Write-Output "Root Path: $rootPath"
    Write-Output "Query Path: $queryPath"
    Write-Output "Output Path: $outputPath"

    # Create output folder

    if (!(Test-Path $outputPath)) {

        New-Item `
        -ItemType Directory `
        -Path $outputPath `
        -Force `
        -ErrorAction Stop | Out-Null
    }

    Write-Output "Output directory ready"
}
catch {

    Write-Error "Failed while setting dynamic paths"

    Write-Error $_.Exception.Message

    throw
}

# ================================
# RUN ORPHAN RESOURCE QUERIES
# ================================

try {

    Write-Output "========================================"
    Write-Output "Starting orphan resource queries..."
    Write-Output "========================================"

    if (!(Test-Path $queryPath)) {

        throw "Queries folder not found: $queryPath"
    }

    $queryFiles = Get-ChildItem `
    -Path $queryPath `
    -Filter "*.kql" `
    -ErrorAction Stop

    Write-Output "Total query files found: $($queryFiles.Count)"

    $allResults = @()

    foreach ($queryFile in $queryFiles) {

        $queryName = $queryFile.BaseName

        Write-Output "========================================"
        Write-Output "Running query: $queryName"
        Write-Output "========================================"

        try {

            $query = Get-Content `
            -Path $queryFile.FullName `
            -Raw `
            -Encoding UTF8 `
            -ErrorAction Stop

            if ([string]::IsNullOrWhiteSpace($query)) {

                Write-Warning "Skipping empty query file: $($queryFile.Name)"

                continue
            }

            Write-Output "Executing Resource Graph query"

            $results = Search-AzGraph `
            -Query $query `
            -First 1000 `
            -ErrorAction Stop

            if ($results) {

                Write-Output "Records fetched: $($results.Count)"

                foreach ($row in $results) {

                    $row | Add-Member `
                    -MemberType NoteProperty `
                    -Name QueryName `
                    -Value $queryName `
                    -Force
                }

                $allResults += $results
            }
            else {

                Write-Output "Records fetched: 0"
            }

            Write-Output "Completed query successfully: $queryName"
        }
        catch {

            Write-Warning "FAILED QUERY: $queryName"

            Write-Warning $_.Exception.Message

            continue
        }
    }

    # Export CSV

    Write-Output "========================================"
    Write-Output "Exporting orphan report"
    Write-Output "========================================"

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

    $csvFileName = "orphan-report-$timestamp.csv"

    $orphanCsv = Join-Path $outputPath $csvFileName
    

if ($allResults.Count -gt 0) {

    Write-Output "Formatting clean orphan report..."


# ========================================
# BUILD SUBSCRIPTION LOOKUP
# ========================================

Write-Output "Building subscription lookup..."

$subscriptionLookup = @{}

Get-AzSubscription | ForEach-Object {

    $subscriptionLookup[$_.Id] = $_.Name
}

Write-Output "Subscription lookup completed"


$cleanReport = $allResults | ForEach-Object {

    # Extract resource name

    $resourceName = ($_.Resource -split "/")[-1]

    # Extract resource type

    $resourceType = "Unknown"

    if ($_.Resource -match "/providers/") {

        $providerPart = ($_.Resource -split "/providers/")[1]

        $resourceType = (
            $providerPart -split "/"
        )[0..1] -join "/"
    }

    # Build clean tag string

    $formattedTags = "NA"

    if ($_.tags) {

        $formattedTags = (
            $_.tags.PSObject.Properties | ForEach-Object {

                "$($_.Name)=$($_.Value)"
            }
        ) -join "; "
    }

    # Build clean report object

    [PSCustomObject]@{

        Subscription = if (
                            $subscriptionLookup.ContainsKey($_.subscriptionId)
                         ) {

                            $subscriptionLookup[$_.subscriptionId]
                         }
                         else {

                            $_.subscriptionId
                         }

        ResourceName  = $resourceName

        ResourceType  = $resourceType

        ResourceGroup = $_.resourceGroup

        Location      = $_.location

        Tags          = $formattedTags
    }
}


    # Export clean CSV

    $cleanReport | Export-Csv `
    -Path $orphanCsv `
    -NoTypeInformation `
    -Force `
    -ErrorAction Stop

    Write-Output "Orphan report exported successfully"

    Write-Output "CSV Path: $orphanCsv"

    Write-Output "Total orphan resources: $($cleanReport.Count)"
}

    else {

        Write-Warning "No orphan resources found"

        "No orphan resources found" | Out-File `
        -FilePath $orphanCsv `
        -Force
    }
}
catch {

    Write-Error "Failed during orphan reporting"

    Write-Error $_.Exception.Message

    throw
}

# ================================
# UPLOAD TO BLOB STORAGE
# ================================

# ================================
# UPLOAD TO BLOB STORAGE
# ================================

try {

    Write-Output "========================================"
    Write-Output "Uploading reports to Blob Storage..."
    Write-Output "========================================"

    $ctx = New-AzStorageContext `
    -StorageAccountName $storageAccountName `
    -UseConnectedAccount

    $files = Get-ChildItem `
    -Path $outputPath `
    -File `
    -ErrorAction Stop

    foreach ($file in $files) {

        $blobName = "$(Get-Date -Format 'yyyy/MM')/$($file.Name)"

        Write-Output "Uploading blob: $blobName"

        Set-AzStorageBlobContent `
        -File $file.FullName `
        -Container $blobContainerName `
        -Blob $blobName `
        -Context $ctx `
        -Force `
        -ErrorAction Stop
    }

    Write-Output "Blob upload completed"
}
catch {

    Write-Error "Blob upload failed"

    Write-Error $_.Exception.Message

    throw
}

# ================================
# GET GRAPH TOKEN
# ================================

try {

    Write-Output "Getting Graph token..."

    $tokenBody = @{

        client_id     = $clientId

        scope         = "https://graph.microsoft.com/.default"

        client_secret = $clientSecret

        grant_type    = "client_credentials"
    }

    $tokenResponse = Invoke-RestMethod `
    -Method POST `
    -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
    -Body $tokenBody `
    -ContentType "application/x-www-form-urlencoded"

    $token = $tokenResponse.access_token

    Write-Output "Graph token acquired"
}
catch {

    Write-Error "Failed to get Graph token"

    Write-Error $_.Exception.Message

    throw
}

# ================================
# BUILD EMAIL
# ================================

$emailBody = @{
    message = @{

        subject = "Azure Orphan Resource Report"

        body = @{
            contentType = "HTML"

            content = @"
<html>
<body>

<p>Hello Team,</p>

<p>PFA updated orphan resources report.</p>

<p>Regards,<br>
Synergetics Cloud Team</p>

</body>
</html>
"@
        }

        toRecipients = @()

        ccRecipients = @()

        attachments = @()
    }

    saveToSentItems = $true
}


# ================================
# BUILD TO RECIPIENTS
# ================================

foreach ($email in $toRecipientsRaw.Split(",")) {

    $emailBody.message.toRecipients += @{

        emailAddress = @{

            address = $email.Trim()
        }
    }
}

# ================================
# BUILD CC RECIPIENTS
# ================================

if (![string]::IsNullOrWhiteSpace($ccRecipientsRaw)) {

    foreach ($email in $ccRecipientsRaw.Split(",")) {

        $emailBody.message.ccRecipients += @{

            emailAddress = @{

                address = $email.Trim()
            }
        }
    }
}

# ================================
# ATTACH FILES
# ================================

try {

    $files = Get-ChildItem `
    -Path $outputPath `
    -File `
    -ErrorAction Stop

    foreach ($file in $files) {

        Write-Output "Attaching file: $($file.Name)"

        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)

        $encoded = [Convert]::ToBase64String($bytes)

        $attachment = @{
            "@odata.type" = "#microsoft.graph.fileAttachment"
            name          = $file.Name
            contentBytes  = $encoded
        }

        $emailBody.message.attachments += $attachment
    }

    Write-Output "All files attached"
}
catch {

    Write-Error "Failed attaching files"

    Write-Error $_.Exception.Message

    throw
}

# ================================
# SEND MAIL
# ================================

try {

    Write-Output "Sending email..."

    Invoke-RestMethod `
    -Method POST `
    -Uri "https://graph.microsoft.com/v1.0/users/$mailSender/sendMail" `
    -Headers @{
        Authorization = "Bearer $token"
    } `
    -Body ($emailBody | ConvertTo-Json -Depth 15) `
    -ContentType "application/json"

    Write-Output "Email sent successfully"
}
catch {

    Write-Error "Email sending failed"

    Write-Error $_.Exception.Message

    throw
}

# ================================
# CLEANUP
# ================================

try {

    Get-ChildItem `
    -Path $outputPath `
    -File `
    -ErrorAction SilentlyContinue | Remove-Item `
    -Force `
    -ErrorAction SilentlyContinue

    Write-Output "Cleanup completed"
}
catch {

    Write-Warning "Cleanup skipped"
}

# ================================
# COMPLETED
# ================================

Write-Output "========================================"
Write-Output "Azure Orphan Reporting Completed"
Write-Output "Time: $(Get-Date)"
Write-Output "========================================"