<#
.SYNOPSIS
    Enables given list of applications to all registered customers
.DESCRIPTION
    Reads "access application" entitlements for the given applications IDs from entitlements database and also reads the list of customers from
    the customers database and assigns the specified entitlement to all registered customers.
    
.EXAMPLE
    - To add entitlement, use the below command
    ./enable-disable-applications-to-customers.ps1 -resourceSubscriptionId xxxxxxxx -resourceGroupName Poseidon-RG -entitlementsCosmosDbAccountName poseidon-next -entitlementsCosmosDbName PN-QA-AAD -entitlementsContainerName PoseidonNext -customersCosmosDbAccountName poseidon-next -customersCosmosDbName PN-QA-AAD -customersContainerName PoseidonNext -applicationIDs "8a966f36-3bba-4ffc-889c-1d6a79b8bebd","a39a5df9-38b4-4ed2-8534-566c535d244b","a563d40a-32c8-4f0d-9755-0047bd01b0cd" -entitlementNames "Access Application","Invoke Trigger" -addEmptyPartitionKey $true -whatIf $true

    - To remove entitlement, we need to add extra parameter -remove $true
    ./enable-disable-applications-to-customers.ps1 -resourceSubscriptionId xxxxxxxx -resourceGroupName Poseidon-RG -entitlementsCosmosDbAccountName poseidon-next -entitlementsCosmosDbName PN-QA-AAD -entitlementsContainerName PoseidonNext -customersCosmosDbAccountName poseidon-next -customersCosmosDbName PN-QA-AAD -customersContainerName PoseidonNext -applicationIDs "8a966f36-3bba-4ffc-889c-1d6a79b8bebd","a39a5df9-38b4-4ed2-8534-566c535d244b","a563d40a-32c8-4f0d-9755-0047bd01b0cd" -entitlementNames "Access Application","Invoke Trigger" -addEmptyPartitionKey $true -whatIf $true -remove $true

.NOTES
    Author: Kongsberg Digital.

    Prerequisites:
    - PowerShell Module: CosmosDB 4.5.0 or higher
    - PowerShell Module: Az
    - PowerShell Module: Az.Resources
    
    NOTE: The user who executes the script must have the following permissions in Azure:
     - access to the specified ResourceGroup/CosmosDB for Customer API and Entitlements
#>

param (
    [string]$resourceSubscriptionId,
    [string]$resourceTenantId = "bf7cb870-b378-42ab-a618-31704bc2e9b7",
    [string]$resourceGroupName,
    [string]$entitlementsCosmosDbAccountName,
    [string]$entitlementsCosmosDbName = "PN-QA-AAD",
    [string]$entitlementsContainerName = "PoseidonNext",    
    [string]$customersCosmosDbAccountName,
    [string]$customersCosmosDbName = "PN-QA-AAD",
    [string]$customersContainerName = "PoseidonNext",
    [string]$applicationIDs,
    [string[]]$entitlementNames = "Access Application",
    [string]$remove = $false,
    [boolean]$addEmptyPartitionKey = $false,
    [boolean]$whatIf = $true
)

# validate input parameters
$inputParametersValid = $true
if (-not $resourceSubscriptionId) { 
    $inputParametersValid = $false
    Write-Host "The parameter -resourceSubscriptionId is required"
}

if (-not $resourceTenantId) { 
    $inputParametersValid = $false
    Write-Host "The parameter -resourceTenantId is required"
}

if (-not $resourceGroupName) { 
    $inputParametersValid = $false
    Write-Host "The parameter -resourceGroupName is required"
}

if (-not $entitlementsCosmosDbAccountName) { 
    $inputParametersValid = $false
    Write-Host "The parameter -entitlementsCosmosDbAccountName is required"
}

if (-not $entitlementsCosmosDbName) { 
    $inputParametersValid = $false
    Write-Host "The parameter -entitlementsCosmosDbName is required"
}

if (-not $entitlementsContainerName) { 
    $inputParametersValid = $false
    Write-Host "The parameter -entitlementsContainerName is required"
}

if (-not $customersCosmosDbAccountName) { 
    $inputParametersValid = $false
    Write-Host "The parameter -customersCosmosDbAccountName is required"
}

if (-not $customersCosmosDbName) { 
    $inputParametersValid = $false
    Write-Host "The parameter -customersCosmosDbName is required"
}

if (-not $customersContainerName) { 
    $inputParametersValid = $false
    Write-Host "The parameter -customersContainerName is required"
}

if (-not $applicationIDs) { 
    $inputParametersValid = $false
    Write-Host "The parameter -applicationIDs is required"
}

if (-not $entitlementNames) { 
    $inputParametersValid = $false
    Write-Host "The parameter -entitlementNames is required"
}

if (-not $inputParametersValid) {
    exit 1
}

if ($whatIf) { 
    Write-Host "THIS IS A DRY RUN. Specify -whatIf `$false for actual execution."
}

<#
.SYNOPSIS
    Validates the connection to an Azure CosmosDB database and throws and exception if the connection is not possible
#>
function Test-DatabaseAndCollection {    
    param (
        $cosmosDbAccountName,
        $dbName,
        $collectionId,
        $primaryKey
    )
    
    $cosmosDbContext = New-CosmosDbContext -Account $cosmosDbAccountName -Database $dbName -Key $primaryKey
    if ((Get-CosmosDbDatabase -Context $cosmosDbContext | Where-Object Id -eq $dbName).Count -eq 0) {
        throw "Database $dbName does not exist"
    }

    if ((Get-CosmosDbCollection -Context $cosmosDbContext | Where-Object id -eq $collectionId).Count -eq 0) {
        throw "Collection $collectionId does not exist in database $dbName"
    }
}

<#
.SYNOPSIS
    Gets an document from CosmosDB and returns it as a string
#>
function Get-CosmosDbDocumentAsString {
    param (
        [string] $cosmosDbAccountName,
        [string] $dbName,
        [string] $collectionId,
        [SecureString] $primaryKey,
        [string] $query = $null
    )
    
    # check if either the $recordId or $query parameter is supplied
    if ((-not $recordId) -and (-not $query)) { return $null }
    $cosmosDbContext = New-CosmosDbContext -Account $cosmosDbAccountName -Database $dbName -Key $primaryKey
    $response = $null
    try {
        $response = Get-CosmosDbDocument -Context $cosmosDbContext -CollectionId $collectionId -Query $query -ReturnJson -QueryEnableCrossPartition $addEmptyPartitionKey
    }
    catch {
        if ($_.Exception.Response.StatusCode.Value__ -eq 404) { 
            # a document with this ID was not found
            $response = $null
        }
        else {
            throw $_
        }
    }
    
    return $response
}

<#
.SYNOPSIS
    Creates a document in the CosmosDB database. The document body is passed through the $documentBody parameter as a string.
#>
function New-DocumentIfNotExisting {
    param (
        [string] $cosmosDbAccountName,
        [string] $dbName,
        [string] $collectionId,
        [securestring] $primaryKey,
        [string] $documentId,
        [string] $documentBody,
        [bool] $overrideExisting = $false
    )
    
    $global:cosmosDbContext = New-CosmosDbContext -Account $cosmosDbAccountName -Database $dbName -Key $primaryKey
    $global:resourcePath = ('colls/{0}/docs' -f $collectionId)
    $global:headers = @{ }

    $global:headers += @{
        'x-ms-documentdb-is-upsert' = $overrideExisting
    }

    $global:postBody = $documentBody

    $global:headers += @{
        'x-ms-documentdb-query-enablecrosspartition' = $true
    }
    if ($addEmptyPartitionKey -eq $true) {
        $global:headers += @{
            'x-ms-documentdb-partitionkey' = '[{}]'
        }
    }

    $temp = $postBody | ConvertFrom-Json -AsHashTable | ConvertTo-Json
    if ($whatIf) {
        Write-Host "Would insert document: " $temp
    }
    else {
        $global:docid = "ue:$documentId"
        & $cosmosDbModule { 
            $documentId = $global:docid
            try {
                $response = Invoke-CosmosDbRequest -Context $cosmosDbContext -Method 'Post' -ResourceType 'docs' -ResourcePath $resourcePath -Body $postBody -Headers $headers -ApiVersion "2018-09-17"
                Write-Host "Inserted document: " $temp
                if ($response -and $response.Content) {
                    Write-Host "Added a document with id: $documentId (status code: " $response.StatusCode ")"
                }
                else {
                    Write-Host "No readable response for document with id: $documentId (status code: " $response.StatusCode ")"
                }
            }
            catch {
                if ($_.Exception.Response.StatusCode -eq 409) {
                    Write-Host "Document already exists with the same ID: $documentId" 
                }
                else {
                    Write-Host "Error occurred: " $_.Exception.Message 
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Gets an "UserEntitlement" type of document from the entitlements database, specifyed by userId. Returns the document as a string.
#>
function Get-EntitlementsForUser {
    param (
        [string] $cosmosDbAccountName,
        [string] $dbName,
        [string] $collectionId,
        [securestring] $primaryKey,
        [string] $userId
    )
    
    # check that the userId parameter is supplied
    if (-not $userId) { return $null }

    # the UserEntitlement record has the format ue:<user-id>
    $userEntitlementId = "ue:" + $userId

    $entitlementsQuery = "SELECT * FROM c WHERE c.id = ""$userEntitlementId""";
    
    return Get-CosmosDbDocumentAsString -query $entitlementsQuery -cosmosDbAccountName $cosmosDbAccountName -dbName $dbName -collectionId $collectionId -primaryKey $primaryKey
}

<#
.SYNOPSIS
    Gets a list of tenant IDs from Customers Database
#>
function Get-CustomerTenantIds {
    param (
        [string] $cosmosDbAccountName, 
        [string] $dbName, 
        [string] $collectionId, 
        [securestring] $primaryKey
    )
    
    $tenantIds = @{}
    $customersQuery = 'SELECT c.Payload.Name, c.Payload.TenantId, c.Payload.OidcURL FROM c WHERE c.PayloadType = "kognifai.Customer.API.Models.Customer"'
    $customersQueryResult = Get-CosmosDbDocumentAsString -query $customersQuery -cosmosDbAccountName $cosmosDbAccountName -dbName $dbName -collectionId $collectionId -primaryKey $primaryKey
    if ($customersQueryResult) {
        $customersQueryResultJson = $customersQueryResult | ConvertFrom-Json
        Write-Host "There are " $customersQueryResultJson._count " customers in the Customers Database"

        foreach ($customer in $customersQueryResultJson.Documents) {
            $customerName = $customer.Name

            $tid = $customer.TenantId
            if (-not $tid) {
                # some customers don't have the TenantId property, then get it from the OidcURL
                $tid = $customer.OidcURL.Replace('https://login.microsoftonline.com/', '').TrimEnd('/')
            }

            if ($tid) {
                if ($tenantIds.ContainsKey($tid)) {
                    Write-Host "Warning: Duplicate tenant IDs in the customers database: $tid"
                }
                else {
                    $ignore = $tenantIds.Add($tid, $customerName)
                }
            }
            else {
                Write-Host "Unable to find the tenant id for customer $customerName"
            }
        }
    }

    return $tenantIds
}

<#
.SYNOPSIS
    Retrieves entitlement IDs for a given set of application IDs using a primary key.
.PARAMETER applicationIDs
    Specifies the application IDs for which entitlement IDs need to be retrieved.
.PARAMETER entitlementNames
    Specifies the list of entitlement names separated by comma. eg: "Access Application","Invoke Trigger"
.PARAMETER primaryKey
    Specifies the primary key required for authentication and authorization.
#>
function Get-EntitlementIds {
    param (
        [string] $applicationIDs,
        [string[]] $entitlementNames,
        [securestring] $primaryKey
    )

    try {
        $appIDs = $applicationIDs.Split(' ').Trim() -join '","'
        $eNames = $entitlementNames.Split(',').Trim() -join '","'

        $entitlementsQuery = "SELECT c.Payload.Id from c WHERE c.PayloadType = 'Kognifai.Entitlements.API.Models.Entitlement' AND c.Payload.ApplicationId IN (""$appIDs"") AND c.Payload.Name IN (""$eNames"")"

        $entitlementsQueryResult = Get-CosmosDbDocumentAsString -query $entitlementsQuery -cosmosDbAccountName $entitlementsCosmosDbAccountName -dbName $entitlementsCosmosDbName -collectionId $entitlementsContainerName -primaryKey $primaryKey
        $json = ConvertFrom-Json($entitlementsQueryResult);
        $documents = $json.Documents
        $ids = @()
        # Iterate through the Documents array and get the Id of each document
        foreach ($document in $documents) {
            $ids += $document.Id
        }
        return [string[]]$ids
    }
    catch {
        Write-Error "An error occurred while getting entitlementIds: $_"
        exit 1
    }
}

<#
.SYNOPSIS
    Retrieves a customer entitlement document for updating based on user entitlement result and a list of entitlement IDs.
.DESCRIPTION
    This function takes in a user entitlement result and a list of entitlement IDs, and retrieves the corresponding customer entitlement document for updating.
.PARAMETER userEntitlementResult
    Specifies the user entitlement result that contains information about the customer's entitlements.
.PARAMETER entitlementIDs
    Specifies an array of entitlement IDs for which the customer entitlement document needs to be retrieved for updating.
#>
function Get-CustomerEntitlementsDocumentForUpdate {
    param (
        [string] $userEntitlementResult,
        [string[]]$entitlementIDs
    )

    try {
        $result = $userEntitlementResult | ConvertFrom-Json -AsHashTable
    }
    catch {
        throw "Error converting JSON: $_"
    }

    if ($result["Documents"].Count -gt 0) {
        $document = $result["Documents"] | Select-Object -First 1
        $documentId = $document["Id"]
        $temp = $document | ConvertTo-Json
        
        if ($null -eq $document.Payload.EntitlementsIds) {
            $document.Payload.EntitlementsIds = @();
        }
        $assignedEntitlements = $document.Payload.EntitlementsIds
        $updatedEntitlements = $document.Payload.EntitlementsIds
        if ($remove -eq $true)
        {
            $filteredEntitlements = $assignedEntitlements | Where-Object { -not ($entitlementIDs-contains $_) }
            $updatedEntitlements = ($null -eq $filteredEntitlements) ? @() : $filteredEntitlements
        }
        else 
        {
            foreach ($id in $entitlementIDs) {
                if (-not ($assignedEntitlements -contains $id)) {
                    Write-Host "Entitlement add $id"
                    $updatedEntitlements += $id
                }
            }
        }
    
        $document.Payload.EntitlementsIds = $updatedEntitlements
        $newDocument = $document | ConvertTo-Json
    
        return @{
            DocumentId       = $documentId
            OriginalDocument = $temp
            UpdatedDocument  = $newDocument
        }
    }
    else {
        # Handle the case where the "Documents" array is empty
        Write-Host "No documents found."
        return
    }
}

<#
.SYNOPSIS
    Creates a new customer entitlement document with the specified document ID and entitlement IDs.
.DESCRIPTION
    This function is responsible for generating a new customer entitlement document using the provided document ID and a list of entitlement IDs.
.PARAMETER documentId
    Specifies the unique identifier for the customer entitlement document.
.PARAMETER entitlementIDs
    Specifies an array of entitlement IDs to associate with customer's entitlement.
#>
function New-CustomerEntitlementsDocument {
    param(
        [string] $documentId,
        [string[]] $entitlementIDs
    )

    $newDocument = @{}
    $newDocument["_id"] = "ue:$documentId"
    $newDocument["Id"] = "ue:$documentId"
    $newDocument["PayloadType"] = "Kognifai.Entitlements.API.Models.UserEntitlement"
    $payload = @{}
    $payload["Id"] = "$documentId"
    $payload["EntitlementsIds"] = @($entitlementIDs)
    $newDocument["Payload"] = $payload
    $temp = ($newDocument | ConvertTo-Json -Depth 10 -Compress).Replace('"_id":"', '"id":"')
    return $temp
}

<#
.SYNOPSIS
    Updates entitlement information for multiple customers based on the specified customer data, entitlement IDs, and primary key.
.DESCRIPTION
    This function facilitates the update of entitlements for a collection of customers. It internally either creates or updated entitlements for customers.
.PARAMETER customers
    Specifies a hashtable containing customer data where the keys are customer IDs and the values are user entitlement results.
.PARAMETER entitlementIDs
    Specifies an array of entitlement IDs that need to be updated for the specified customers.
.PARAMETER primaryKey
    Specifies the primary key required for authentication and authorization when updating entitlement information.
#>
function Update-Entitlements {
    param(
        [hashtable] $customers,
        [string[]] $entitlementIDs,
        [SecureString] $primaryKey
    )

    $customerIDs = $customers.Keys
    foreach ($customerID in $customerIDs) {
        $customerName = $customers[$customerID]
        $userEntitlementResult = Get-EntitlementsForUser -cosmosDbAccountName $entitlementsCosmosDbAccountName -dbName $entitlementsCosmosDbName -collectionId $entitlementsContainerName -primaryKey $primaryKey -userId $customerID
        try {
            try {
                $eResult = $userEntitlementResult | ConvertFrom-Json -AsHashTable
            }
            catch {
                throw "Error converting JSON: $_"
            }
    
            if ($eResult["Documents"].Count -gt 0) {
                Write-Host
                Write-Host "Updating customer's entitlements: $customerName"
                Write-Host
                $result = Get-CustomerEntitlementsDocumentForUpdate -userEntitlementResult $userEntitlementResult -entitlementIDs $entitlementIDs
                if (-not $whatIf) {
                    Write-Host
                    Write-Host $result.UpdatedDocument
                    New-DocumentIfNotExisting -cosmosDbAccountName $entitlementsCosmosDbAccountName -dbName $entitlementsCosmosDbName -collectionId $entitlementsContainerName -primaryKey $primaryKey -documentId $customerID -documentBody $result.UpdatedDocument -overrideExisting $true
                }
                else {
                    Write-Host "Pre-update for customer $customerName $customerID"
                    Write-Host
                    Write-Host $result.OriginalDocument 
                    Write-Host "Post-update for customer $customerName $customerID"
                    Write-Host
                    Write-Host $result.UpdatedDocument 
                }
            }
            else {
                Write-Host
                Write-Host "Creating customer entitlements: $customerName $customerID"
                $document = New-CustomerEntitlementsDocument -documentId $customerID -entitlementIDs $entitlementIDs
                New-DocumentIfNotExisting -cosmosDbAccountName $entitlementsCosmosDbAccountName -dbName $entitlementsCosmosDbName -collectionId $entitlementsContainerName -primaryKey $primaryKey -documentId $customerID -documentBody $document
            }
        }
        catch {
            Write-Host "Error in update: $_"
        }
    }
}

# ============================================================
# ============================================================
# ============================================================

Write-Host "Checking prerequisites..."
Write-Host
Write-Host "CosmosDB module version 4.5.0 or greater..." -NoNewline 
$valid = $false
foreach ($v in (Get-Module CosmosDB -ListAvailable).Version) { if ($v -ge '4.5.0') { $valid = $true } }
if ($valid) { 
    Write-Host "OK." 
}
else {
    Write-Host "Failed."
    Write-Error "CosmosDB module is required. Start PowerShell as Administrator and install the module using: Install-Module -Name CosmosDB -MinimumVersion 4.5.0"
    exit 1
}

Write-Host "Az module..." -NoNewline 
$valid = $false
if (Get-Module Az.* -ListAvailable) { $valid = $true }
if ($valid) { Write-Host "OK." } else {
    Write-Host "Failed."
    Write-Error "Az.* modules are required. Start PowerShell as Administrator and install the module using: Install-Module -Name Az"
    exit 1
}

Write-Host

# Import the necessary modules
Import-Module Az
Import-Module Az.Resources
Import-Module CosmosDB -MinimumVersion 4.5.0
(get-module -ListAvailable -name CosmosDB)

$cosmosDbModule = Get-Module CosmosDb

# Login to Azure 
Write-Host "Logging in Azure (subscription: $resourceSubscriptionId, tenant: $resourceTenantId) ..."
Connect-AzAccount -TenantId $resourceTenantId -SubscriptionId $resourceSubscriptionId

# get the cosmosdb keys
Write-Host "Validating connection to the Entitlements database (resource group: $resourceGroupName, account: $entitlementsCosmosDbAccountName, db name: $entitlementsCosmosDbName, collection id: $entitlementsContainerName)"
$dbKeyEntitlements = (Invoke-AzResourceAction -Action listKeys -ResourceType "Microsoft.DocumentDb/databaseAccounts" -ResourceGroupName $resourceGroupName -Name $entitlementsCosmosDbAccountName -force).primaryMasterKey
$primaryKeyEntitlements = ConvertTo-SecureString -String $dbKeyEntitlements -AsPlainText -Force
Test-DatabaseAndCollection -cosmosDbAccountName $entitlementsCosmosDbAccountName -dbName $entitlementsCosmosDbName -collectionId $entitlementsContainerName -primaryKey $primaryKeyEntitlements

Write-Host "Validating connection to the Customers database (resource group: $resourceGroupName, account: $customersCosmosDbAccountName, db name: $customersCosmosDbName, collection id: $customersContainerName)"
$dbKeyCustomers = (Invoke-AzResourceAction -Action listKeys -ResourceType "Microsoft.DocumentDb/databaseAccounts" -ResourceGroupName $resourceGroupName -Name $customersCosmosDbAccountName -force).primaryMasterKey
$primaryKeyCustomers = ConvertTo-SecureString -String $dbKeyCustomers -AsPlainText -Force
Test-DatabaseAndCollection -cosmosDbAccountName $customersCosmosDbAccountName -dbName $customersCosmosDbName -collectionId $customersContainerName -primaryKey $primaryKeyCustomers

# Connect to Customers DB to get list of tenant IDs
$customersHash = Get-CustomerTenantIds -cosmosDbAccountName $customersCosmosDbAccountName -dbName $customersCosmosDbName -collectionId $customersContainerName -primaryKey $primaryKeyCustomers

# Get 'access application' entitlement IDs for given application IDs
$entitlementIDs = Get-EntitlementIds -applicationIDs $applicationIDs -entitlementNames $entitlementNames -primaryKey $primaryKeyEntitlements

# Just printing the entitlements IDs to console
if ($null -ne $entitlementIDs) {
    Write-Host "Entitlement IDs:"
    foreach ($entitlementId in $entitlementIDs) {
        Write-Host $entitlementId
    }
}
else {
    Write-Host "Failed to retrieve entitlement IDs."
}

Update-Entitlements -customers $customersHash -entitlementIDs $entitlementIDs -primaryKey $primaryKeyEntitlements
