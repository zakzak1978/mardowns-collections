# PowerShell script to delete user entitlement records not matching IDs in an Excel file
# Based on enable-disable-applications-to-customers.ps1

param (
    [string]$resourceSubscriptionId = "f375a5ca-1961-4503-902a-4fbf75f63fa7",
    [string]$resourceTenantId = "bf7cb870-b378-42ab-a618-31704bc2e9b7",
    [string]$resourceGroupName = "N00482_westeurope",
    [string]$entitlementsCosmosDbAccountName = "n08493-pnext-cosmos-entitlements",
    [string]$entitlementsCosmosDbName = "PoseidonNext",
    [string]$entitlementsContainerName = "PoseidonNext",
    [string]$excelFilePath = "D:\_studyarea\Markdowns\IDP_UserIds.xlsx",
    [string]$userIdColumn = "UserId",  # Column name in Excel with user IDs
    [boolean]$addEmptyPartitionKey = $true,
    [boolean]$whatIf = $true,
    [int]$maxDeletions = 1  # Limit deletions for testing. Set to 0 for unlimited.
)

# Validate input parameters
$inputParametersValid = $true
if (-not $resourceSubscriptionId) {
    $inputParametersValid = $false
    Write-Host "The parameter -resourceSubscriptionId is required"
}
if (-not $resourceGroupName) {
    $inputParametersValid = $false
    Write-Host "The parameter -resourceGroupName is required"
}
if (-not $entitlementsCosmosDbAccountName) {
    $inputParametersValid = $false
    Write-Host "The parameter -entitlementsCosmosDbAccountName is required"
}
if (-not (Test-Path $excelFilePath)) {
    $inputParametersValid = $false
    Write-Host "The Excel file $excelFilePath does not exist"
}
if (-not $inputParametersValid) {
    exit 1
}

if ($whatIf) {
    Write-Host "THIS IS A DRY RUN. Specify -whatIf `$false for actual execution."
}

# Function to read valid user IDs from Excel
function Get-ValidUserIds {
    param ([string]$path, [string]$column)
    try {
        # Read first column without headers - all values are valid user IDs to keep
        Import-Excel -Path $path -NoHeader | Select-Object -ExpandProperty "P1" | Where-Object { $_ }
    } catch {
        Write-Error "Failed to read Excel file: $_"
        exit 1
    }
}

# Function to process documents in pages
function Process-EntitlementsInPages {
    param (
        [string]$cosmosDbAccountName,
        [string]$dbName,
        [string]$collectionId,
        [securestring]$primaryKey,
        [hashtable]$validIds
    )
    
    $pageSize = 1000  # Adjust as needed
    $continuationToken = $null
    $totalProcessed = 0
    $totalDeleted = 0
    $deletionLimitReached = $false
    
    do {
        $cosmosDbContext = New-CosmosDbContext -Account $cosmosDbAccountName -Database $dbName -Key $primaryKey
        $query = "SELECT * FROM c WHERE c.PayloadType = 'Kognifai.Entitlements.API.Models.UserEntitlement'"
        
        try {
            $responseHeader = $null
            $params = @{
                Context = $cosmosDbContext
                CollectionId = $collectionId
                Query = $query
                QueryEnableCrossPartition = $addEmptyPartitionKey
                MaxItemCount = $pageSize
                ReturnJson = $true
                ResponseHeader = [ref]$responseHeader
            }
            if ($continuationToken) {
                $params.ContinuationToken = $continuationToken
            }
            $response = Get-CosmosDbDocument @params
            
            # Get continuation token from response header
            if ($responseHeader -and $responseHeader['x-ms-continuation']) {
                $continuationToken = [string]$responseHeader['x-ms-continuation']
            } else {
                $continuationToken = $null
            }
            
            # When using -ReturnJson, response is JSON string(s), not an object with .Documents
            # Use -AsHashtable to handle keys with different casing (id vs Id)
            if ($response -is [array]) {
                $documents = $response | ForEach-Object { $_ | ConvertFrom-Json -AsHashtable }
            } elseif ($response -is [string]) {
                $parsed = $response | ConvertFrom-Json -AsHashtable
                # Check if it's wrapped in a Documents array
                if ($parsed.ContainsKey('Documents')) {
                    $documents = $parsed['Documents']
                } else {
                    $documents = @($parsed)
                }
            } else {
                $documents = @()
            }
            $totalProcessed += $documents.Count
            
            Write-Host "Processing page with $($documents.Count) documents. Total processed: $totalProcessed"
            
            # Process deletions for this page
            $documentsToDelete = @()
            $documentsToKeep = @()
            foreach ($doc in $documents) {
                # Access 'id' key (lowercase) from hashtable
                $docId = $doc['id']
                $userId = $docId -replace '^ue:', ''
                if ($validIds.ContainsKey($userId)) {
                    $documentsToKeep += $doc
                } else {
                    $documentsToDelete += $doc
                }
            }
            
            Write-Host "  Documents to KEEP (in Excel): $($documentsToKeep.Count)"
            Write-Host "  Documents to DELETE (not in Excel): $($documentsToDelete.Count)"
            if ($documentsToDelete.Count -gt 0 -and $documentsToDelete.Count -le 5) {
                Write-Host "  Sample IDs to delete:"
                $documentsToDelete | ForEach-Object { Write-Host "    - $($_['id'])" }
            }
            
            # Delete in batches
            $batchSize = 100
            for ($i = 0; $i -lt $documentsToDelete.Count; $i += $batchSize) {
                if ($deletionLimitReached) { break }
                $batch = $documentsToDelete[$i..([math]::Min($i + $batchSize - 1, $documentsToDelete.Count - 1))]
                foreach ($delDoc in $batch) {
                    # Check if we've reached the deletion limit
                    if ($maxDeletions -gt 0 -and $totalDeleted -ge $maxDeletions) {
                        Write-Host "Reached maxDeletions limit of $maxDeletions. Stopping."
                        $deletionLimitReached = $true
                        break
                    }
                    $success = Remove-UserEntitlement -cosmosDbAccountName $cosmosDbAccountName -dbName $dbName -collectionId $collectionId -primaryKey $primaryKey -documentId $delDoc['id']
                    if ($success) { $totalDeleted++ }
                    Start-Sleep -Milliseconds 100
                }
            }
        } catch {
            Write-Error "Error processing page: $_"
            break
        }
    } while ($continuationToken -and -not $deletionLimitReached)
    
    Write-Host "Finished processing. Total documents scanned: $totalProcessed, Total deleted: $totalDeleted"
}

# Function to delete a document
function Remove-UserEntitlement {
    param (
        [string]$cosmosDbAccountName,
        [string]$dbName,
        [string]$collectionId,
        [securestring]$primaryKey,
        [string]$documentId
    )
    $global:deleteCosmosDbContext = New-CosmosDbContext -Account $cosmosDbAccountName -Database $dbName -Key $primaryKey
    $global:deleteCollectionId = $collectionId
    $global:deleteDocumentId = $documentId
    
    try {
        if ($whatIf) {
            Write-Host "Would delete document: $documentId"
            return $true
        } else {
            if ($addEmptyPartitionKey) {
                # For legacy containers, try delete without partition key header first
                $global:deleteResourcePath = "colls/$deleteCollectionId/docs/$deleteDocumentId"
                $cosmosDbModule = Get-Module CosmosDb
                & $cosmosDbModule {
                    Invoke-CosmosDbRequest -Context $global:deleteCosmosDbContext -Method 'Delete' -ResourceType 'docs' -ResourcePath $global:deleteResourcePath
                }
            } else {
                Remove-CosmosDbDocument -Context $global:deleteCosmosDbContext -CollectionId $collectionId -Id $documentId
            }
            Write-Host "Deleted document: $documentId"
            return $true
        }
    } catch {
        Write-Error "Failed to delete document ${documentId}: $_"
        return $false
    }
}

# Prerequisites check (similar to original)
Write-Host "Checking prerequisites..."
$valid = $false
foreach ($v in (Get-Module CosmosDB -ListAvailable).Version) { if ($v -ge '4.5.0') { $valid = $true } }
if (-not $valid) {
    Write-Error "CosmosDB module 4.5.0+ required."
    exit 1
}
if (-not (Get-Module ImportExcel -ListAvailable)) {
    Write-Error "ImportExcel module required. Install with: Install-Module -Name ImportExcel"
    exit 1
}

Import-Module Az
Import-Module CosmosDB
Import-Module ImportExcel

# Login to Azure
Connect-AzAccount -TenantId $resourceTenantId -SubscriptionId $resourceSubscriptionId

# List Cosmos DB accounts
$accounts = Get-AzCosmosDBAccount -ResourceGroupName $resourceGroupName
Write-Host "Available Cosmos DB accounts:"
$accounts | ForEach-Object { Write-Host "  - $($_.Name) in RG $($_.ResourceGroupName)" }

# Get keys
$dbKey = (Invoke-AzResourceAction -Action listKeys -ResourceType "Microsoft.DocumentDb/databaseAccounts" -ResourceGroupName $resourceGroupName -Name $entitlementsCosmosDbAccountName -Force).primaryMasterKey
$primaryKey = ConvertTo-SecureString -String $dbKey -AsPlainText -Force

# Test connection
$cosmosDbContext = New-CosmosDbContext -Account $entitlementsCosmosDbAccountName -Key $primaryKey
try {
    $databases = Get-CosmosDbDatabase -Context $cosmosDbContext
    Write-Host "Connected successfully. Found databases: $($databases.Name -join ', ')"
} catch {
    Write-Error "Failed to connect or list databases: $_"
    exit 1
}

# Read valid user IDs
$validUserIds = Get-ValidUserIds -path $excelFilePath -column $userIdColumn
Write-Host "Loaded $($validUserIds.Count) valid user IDs from Excel."

# Convert to hash set for fast lookups
$validIds = @{}
$validUserIds | ForEach-Object { $validIds[$_] = $true }
Write-Host "Converted to hash set for efficient lookups."

# Process entitlements in pages
Process-EntitlementsInPages -cosmosDbAccountName $entitlementsCosmosDbAccountName -dbName $entitlementsCosmosDbName -collectionId $entitlementsContainerName -primaryKey $primaryKey -validIds $validIds

Write-Host "Deletion process complete."