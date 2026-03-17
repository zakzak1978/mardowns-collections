# PowerShell script to backup Cosmos DB data
# Requires: The Cosmos DB account endpoint, key, database name, container name

param (
    [string]$Endpoint = "https://n08493-pnext-cosmos-entitlements.documents.azure.com:443/",
    [string]$Key = "eyqwotw4AhPc7ekNDVtYwAyOb0dgfSwE5mqaOdVrO1ojwKmyFHku4PPw5NTZ6tDC2bnSNaPJd39AAt5h00fSKQ==",
    [string]$Database = "PoseidonNext",
    [string]$Container = "PoseidonNext",
    [string]$BackupFilePath = "cosmos_backup.json"  # Path to save backup
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

# Function to export all documents to a JSON file
function Export-CosmosDocuments {
    param (
        [string]$Uri,
        [hashtable]$Headers,
        [string]$FilePath
    )
    
    $allDocuments = @()
    $continuationToken = $null
    
    do {
        $queryHeaders = $Headers.Clone()
        if ($continuationToken) {
            $queryHeaders["x-ms-continuation"] = $continuationToken
        }
        
        $request = [System.Net.WebRequest]::Create($Uri)
        $request.Method = "POST"
        $request.ContentType = "application/json"
        foreach ($key in $queryHeaders.Keys) {
            $request.Headers.Add($key, $queryHeaders[$key])
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
        $allDocuments += $json.Documents
        $continuationToken = $json.'x-ms-continuation'
    } while ($continuationToken)
    
    $allDocuments | ConvertTo-Json -Depth 10 | Out-File -FilePath $FilePath -Encoding UTF8
    Write-Host "Backup saved to $FilePath"
}

# Get current date in RFC1123 format
$date = [DateTime]::UtcNow.ToString("r")

# Backup all documents
$query = "SELECT * FROM c"
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

Export-CosmosDocuments -Uri $queryUri -Headers $headers -FilePath $BackupFilePath