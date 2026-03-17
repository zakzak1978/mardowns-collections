# PowerShell script to perform container copy in Cosmos DB
# Assumes Azure CLI is installed and logged in (az login)
# Requires: Account name, database name, source container name, target container name

param (
    [string]$AccountName = "n08493-pnext-cosmos-entitlements",
    [string]$DatabaseName = "PoseidonNext",
    [string]$SourceContainer = "PoseidonNext",
    [string]$TargetContainer = "PoseidonNext_backup"
)

# Get resource group
$ResourceGroup = az cosmosdb show --name $AccountName --query resourceGroup -o tsv
if (-not $ResourceGroup) {
    Write-Error "Could not find resource group for account $AccountName"
    exit
}
Write-Host "Resource Group: $ResourceGroup"

# Get source container configuration
$ConfigJson = az cosmosdb sql container show --account-name $AccountName --resource-group $ResourceGroup --database-name $DatabaseName --name $SourceContainer --query "{partitionKey:partitionKey, indexingPolicy:indexingPolicy, defaultTtl:defaultTtl, uniqueKeyPolicy:uniqueKeyPolicy}" -o json
$Config = $ConfigJson | ConvertFrom-Json

# Extract partition key path
$PartitionKeyPath = $Config.partitionKey.paths[0]  # Assuming single partition key
Write-Host "Partition Key Path: $PartitionKeyPath"

# Create target container (must be empty)
az cosmosdb sql container create --account-name $AccountName --resource-group $ResourceGroup --database-name $DatabaseName --name $TargetContainer --partition-key-path $PartitionKeyPath --partition-key-kind Hash --throughput 400  # Adjust throughput as needed

# Perform container copy (this may take time for large containers)
az cosmosdb sql container copy --account-name $AccountName --resource-group $ResourceGroup --database-name $DatabaseName --name $SourceContainer --target-database-name $DatabaseName --target-container-name $TargetContainer

Write-Host "Container copy initiated. Monitor the operation in Azure portal."