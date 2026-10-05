#Requires -Version 5.1
param([switch]$Quiet)

if (-not $Quiet) {
    Write-Host ""
    Write-Host "  CORS proxy ayri calistirilmaz." -ForegroundColor Yellow
    Write-Host "  Uygulamayi acmak icin proje kokunde: .\run.ps1" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$port = 8766
$prefix = "http://localhost:$port/"

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()

$cors = @{
    'Access-Control-Allow-Origin'  = '*'
    'Access-Control-Allow-Methods'   = 'GET, OPTIONS'
    'Access-Control-Allow-Headers'   = '*'
}

function Write-Response($ctx, [int]$code, [byte[]]$bytes, [string]$contentType) {
    $ctx.Response.StatusCode = $code
    $ctx.Response.ContentType = $contentType
    $ctx.Response.ContentLength64 = $bytes.Length
    foreach ($k in $cors.Keys) { $ctx.Response.Headers[$k] = $cors[$k] }
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.OutputStream.Close()
}

function Write-Text($ctx, [int]$code, [string]$text) {
    Write-Response $ctx $code ([Text.Encoding]::UTF8.GetBytes($text)) 'text/plain; charset=utf-8'
}

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request

    if ($req.HttpMethod -eq 'OPTIONS') {
        Write-Text $ctx 204 ''
        continue
    }

    if ($req.Url.AbsolutePath -ne '/proxy') {
        Write-Text $ctx 404 'Not found. Use /proxy?url=<encoded>'
        continue
    }

    $target = $req.QueryString['url']
    if ([string]::IsNullOrWhiteSpace($target)) {
        Write-Text $ctx 400 'Missing url query parameter'
        continue
    }

    try {
        $resp = Invoke-WebRequest -Uri $target -UseBasicParsing -TimeoutSec 30 -Headers @{ 'User-Agent' = 'MinimalPodcast/1.0' }
        # Ham baytlar aynen iletilir: [string]$resp.Content ses dosyalarini ve
        # charset belirtmeyen RSS'lerdeki Turkce karakterleri bozuyordu.
        $bytes = $resp.RawContentStream.ToArray()
        $type = if ($resp.Headers['Content-Type']) { [string]$resp.Headers['Content-Type'] } else { 'application/octet-stream' }
        Write-Response $ctx 200 $bytes $type
    } catch {
        Write-Text $ctx 502 "Upstream fetch failed: $($_.Exception.Message)"
    }
}
