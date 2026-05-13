param($Timer)

# ================================
# CONFIGURATION
# ================================

$storageAccountName = $env:STORAGE_ACCOUNT_NAME
$blobContainerName  = $env:BLOB_CONTAINER_NAME

$mailSender = "actual@domain.com"
$mailRecipient = "actual@domain.com"

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

        $allResults | Export-Csv `
        -Path $orphanCsv `
        -NoTypeInformation `
        -Force `
        -ErrorAction Stop

        Write-Output "Orphan report exported successfully"

        Write-Output "CSV Path: $orphanCsv"

        Write-Output "Total orphan resources: $($allResults.Count)"
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

    $token = (
        Get-AzAccessToken `
        -ResourceUrl "https://graph.microsoft.com"
    ).Token

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
<h2>Azure Orphan Resource Report</h2>

<p>Please find attached the latest orphan resource report.</p>
"@
        }

        toRecipients = @(
            @{
                emailAddress = @{
                    address = $mailRecipient
                }
            }
        )

        attachments = @()
    }

    saveToSentItems = $true
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
