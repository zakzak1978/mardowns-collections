# PowerShell script to get Cosmos DB container configuration
# Requires: The Cosmos DB account endpoint, key, database name, container name

param (
    [string]$Endpoint = "https://n08493-pnext-cosmos-entitlements.documents.azure.com:443/",
    [string]$Key = "eyqwotw4AhPc7ekNDVtYwAyOb0dgfSwE5mqaOdVrO1ojwKmyFHku4PPw5NTZ6tDC2bnSNaPJd39AAt5h00fSKQ==",
    [string]$Database = "PoseidonNext",
    [string]$Container = "PoseidonNext"
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

# Get container configuration
$resourceId = "dbs/$Database/colls/$Container"
$authHeader = Get-CosmosAuthHeader -Verb "GET" -ResourceType "colls" -ResourceId $resourceId -Date $date

$uri = "$Endpoint$resourceId"
$headers = @{
    "Authorization" = $authHeader
    "x-ms-date" = $date
    "x-ms-version" = "2018-12-31"
}

try {
    $request = [System.Net.WebRequest]::Create($uri)
    $request.Method = "GET"
    foreach ($key in $headers.Keys) {
        $request.Headers.Add($key, $headers[$key])
    }
    
    $response = $request.GetResponse()
    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
    $content = $reader.ReadToEnd()
    $reader.Close()
    $response.Close()
    
    $config = $content | ConvertFrom-Json
    Write-Host "Container Configuration:"
    $config | ConvertTo-Json -Depth 10
} catch {
    Write-Error "Failed to get container configuration: $_"
}