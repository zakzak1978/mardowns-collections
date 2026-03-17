# Delete Unmatched Entitlements Script Documentation

## Overview
This PowerShell script deletes user entitlement records from Azure Cosmos DB that do not match user IDs listed in an Excel file. It is based on the `enable-disable-applications-to-customers.ps1` script and uses the CosmosDB PowerShell module for database operations.

## Prerequisites
- PowerShell 5.1 or higher
- Azure CLI or Az PowerShell module for authentication
- CosmosDB PowerShell module (version 4.5.0+)
- ImportExcel module for reading Excel files
- Access to the specified Azure subscription, resource group, and Cosmos DB account

## Parameters
- `resourceSubscriptionId`: Azure subscription ID (required)
- `resourceTenantId`: Azure tenant ID (default: bf7cb870-b378-42ab-a618-31704bc2e9b7)
- `resourceGroupName`: Resource group name (required)
- `entitlementsCosmosDbAccountName`: Cosmos DB account name (required)
- `entitlementsCosmosDbName`: Database name (default: PN-QA-AAD)
- `entitlementsContainerName`: Container name (default: PoseidonNext)
- `excelFilePath`: Path to Excel file with user IDs (default: D:\_studyarea\Markdowns\IDP_UserIds.xlsx)
- `userIdColumn`: Column name in Excel (default: UserId; uses first column if no headers)
- `addEmptyPartitionKey`: Enable cross-partition queries (default: false)
- `whatIf`: Dry run mode (default: true)

## Script Flow

1. **Parameter Validation**: Checks required parameters and file existence.
2. **Prerequisites Check**: Verifies installed modules (CosmosDB, ImportExcel).
3. **Azure Login**: Connects to Azure using Az module.
4. **Key Retrieval**: Gets Cosmos DB primary key via Azure Resource Manager.
5. **Excel Reading**: Loads valid user IDs and converts to a hash set for O(1) lookups.
6. **Paged Processing**: Retrieves and processes documents in pages of 1000 to avoid loading all 130K into memory. For each page, compares against the hash set and deletes unmatched in batches of 100 with delays.
7. **Completion**: Logs progress per page and total processed.

## Function Explanations

### Get-ValidUserIds
- **Purpose**: Reads user IDs from the Excel file.
- **Flow**:
  - If column is "UserId" (default), assumes no headers and reads the first column (P1).
  - Otherwise, reads the specified column assuming headers exist.
  - Returns an array of user IDs.
- **Error Handling**: Exits on read failure.

### Get-AllUserEntitlements
- **Purpose**: Queries all user entitlement documents from Cosmos DB.
- **Flow**:
  - Creates Cosmos DB context with account, database, and key.
  - Executes query: `SELECT * FROM c WHERE c.PayloadType = 'Kognifai.Entitlements.API.Models.UserEntitlement'`
  - Enables cross-partition if specified.
  - Returns array of documents.
- **Error Handling**: Returns empty array on failure.

### Remove-UserEntitlement
- **Purpose**: Deletes a single user entitlement document.
- **Flow**:
  - Creates Cosmos DB context.
  - In WhatIf mode, logs the action without deleting.
  - Otherwise, calls `Remove-CosmosDbDocument` with document ID and partition key.
  - Logs success or error.
- **Error Handling**: Catches and logs exceptions.

## Usage Example
```powershell
.\delete-unmatched-entitlements.ps1 -resourceSubscriptionId "12345678-1234-1234-1234-123456789012" -resourceGroupName "MyRG" -entitlementsCosmosDbAccountName "myaccount" -whatIf $true
```

## Notes
- WhatIf mode prevents actual deletions; set to `$false` for production.
- Assumes document IDs are "ue:<userId>"; extracts userId for comparison.
- Partition key is set to document ID; adjust if different.
- For large datasets (e.g., 130k), processes in pages of 1000 to manage memory, with hash set for fast lookups and batched deletions (100 at a time) with delays to manage RU consumption.
- Monitor Azure Portal for RU usage and throttling.
- Backup data before running.

## Troubleshooting
- **401 Error**: Invalid key; verify Azure permissions and key retrieval.
- **Excel Read Error**: Check file path, column name, and ImportExcel installation.
- **Query Errors**: Ensure database/container names and permissions.
- **Deletions Fail**: Check partition key and RU limits.

This script ensures only authorized users retain entitlements, based on the Excel list.