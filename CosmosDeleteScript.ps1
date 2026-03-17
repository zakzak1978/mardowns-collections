# PowerShell script to delete Cosmos DB items not in a list of IDs
# Requires: The Cosmos DB account endpoint, key, database name, container name, and partition key path

param (
    [string]$Endpoint = "https://n08493-pnext-cosmos-entitlements.documents.azure.com:443/",
    [string]$Key = "eyqwotw4AhPc7ekNDVtYwAyOb0dgfSwE5mqaOdVrO1ojwKmyFHku4PPw5NTZ6tDC2bnSNaPJd39AAt5h00fSKQ==",
    [string]$Database = "PoseidonNext",
    [string]$Container = "PoseidonNext",
    [string]$PartitionKeyPath = "/id",  # Adjust if different
    [array]$IdsToKeep = @(1, 2, 3)  # Your list of IDs
)

# Function to generate authorization header
function Get-CosmosAuthHeader {
    param (
        [string]$Verb,
        [string]$ResourceType,
        [string]$ResourceId,
        [string]$Date
    )
    
    $keyBytes = [System.Convert]::FromBase64String($Key)
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = $keyBytes
    
    $stringToSign = "$Verb`n$ResourceType`n$ResourceId`n$Date`n`n"
    $signature = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign))
    $signatureBase64 = [System.Convert]::ToBase64String($signature)
    $signatureBase64 = [System.Net.WebUtility]::UrlEncode($signatureBase64)
    
    return "type=master&ver=1.0&sig=$signatureBase64"
}

# Get current date in RFC1123 format
$date = [DateTime]::UtcNow.ToString("r")

# Query for items not in the list
$query = "SELECT * FROM c WHERE c.id NOT IN ($($IdsToKeep -join ','))"
$resourceId = "dbs/$Database/colls/$Container"
$authHeader = Get-CosmosAuthHeader -Verb "POST" -ResourceType "docs" -ResourceId $resourceId -Date $date

$queryUri = "$Endpoint$resourceId/docs"
$headers = @{
    "Authorization" = $authHeader
    "x-ms-date" = $date
    "x-ms-version" = "2018-12-31"
    "Content-Type" = "application/query+json"
}

$body = @{ query = $query } | ConvertTo-Json

try {
    $request = [System.Net.WebRequest]::Create($queryUri)
    $request.Method = "POST"
    $request.ContentType = "application/json"
    foreach ($key in $headers.Keys) {
        $request.Headers.Add($key, $headers[$key])
    }
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $request.ContentLength = $bodyBytes.Length
    $stream = $request.GetRequestStream()
    $stream.Write($bodyBytes, 0, $bodyBytes.Length)
    $stream.Close()
    
    $response = $request.GetResponse()
    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
    $content = $reader.ReadToEnd()
    $reader.Close()
    $response.Close()
    
    $json = $content | ConvertFrom-Json
    $items = $json.Documents
} catch {
    Write-Error "Failed to query items: $_"
    exit
}

# Delete each item
foreach ($item in $items) {
    $itemId = $item.id
    $partitionKey = $item.($PartitionKeyPath.TrimStart('/'))
    $deleteResourceId = "dbs/$Database/colls/$Container/docs/$itemId"
    $deleteAuthHeader = Get-CosmosAuthHeader -Verb "DELETE" -ResourceType "docs" -ResourceId $deleteResourceId -Date $date
    
    $deleteUri = "$Endpoint$deleteResourceId"
    $deleteHeaders = @{
        "Authorization" = $deleteAuthHeader
        "x-ms-date" = $date
        "x-ms-version" = "2018-12-31"
        "x-ms-documentdb-partitionkey" = "[$partitionKey]"  # Assuming string partition key
    }
    
    try {
        $request = [System.Net.WebRequest]::Create($deleteUri)
        $request.Method = "DELETE"
        foreach ($key in $deleteHeaders.Keys) {
            $request.Headers.Add($key, $deleteHeaders[$key])
        }
        
        $response = $request.GetResponse()
        $response.Close()
        Write-Host "Deleted item with ID: $itemId"
    } catch {
        Write-Error "Failed to delete item $itemId: $_"
    }
}

Write-Host "Deletion complete."