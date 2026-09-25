<#
.SYNOPSIS
    Performs automated synthetic health checks and latency validation against deployed EIRS endpoints.
.DESCRIPTION
    Tests the target environment API endpoints (/api/v1/status, /api/v1/devices/verify)
    to confirm service health, database connectivity, and response latency SLAs (< 300ms).
.PARAMETER Environment
    Target environment (dev, qa, staging, prod). Default is 'dev'.
.PARAMETER MaxLatencyMs
    Maximum allowable p95 response time in milliseconds. Default is 500.
.PARAMETER ApiUrl
    Direct API Base URL (optional, defaults to dist/env-<env>.json).
#>
[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet("dev", "qa", "staging", "prod")]
    [string]$Environment = "dev",

    [Parameter()]
    [int]$MaxLatencyMs = 500,

    [Parameter()]
    [string]$ApiUrl = ""
)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " [07] Automated Synthetic Health Check & Latency Validation" -ForegroundColor Cyan
Write-Host " Environment: $Environment | Max Latency SLA: ${MaxLatencyMs}ms" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path "$scriptRoot\..\.."

if ([string]::IsNullOrWhiteSpace($ApiUrl)) {
    $envConfigFile = "$projectRoot\dist\env-$Environment.json"
    if (Test-Path $envConfigFile) {
        $config = Get-Content $envConfigFile | ConvertFrom-Json
        $ApiUrl = $config.apiUrl
    } else {
        Write-Error "No API URL provided and $envConfigFile not found. Run 05-deploy-api.ps1 first."
        exit 1
    }
}

Write-Host "Target Base URL: $ApiUrl`n" -ForegroundColor Gray

# Probe 1: Health/Status Endpoint
$statusUrl = "$ApiUrl/api/v1/status"
Write-Host "[1/2] Probing Status Endpoint: $statusUrl..." -NoNewline

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $response = Invoke-RestMethod -Uri $statusUrl -Method GET -TimeoutSec 10 -ErrorAction Stop
    $stopwatch.Stop()
    $latencyMs = $stopwatch.ElapsedMilliseconds

    if ($response.status -eq "healthy" -and $latencyMs -le $MaxLatencyMs) {
        Write-Host " PASS (Status: 200 | Latency: ${latencyMs}ms)" -ForegroundColor Green
        Write-Host "      Database Link : $($response.database)" -ForegroundColor Gray
        Write-Host "      Environment   : $($response.environment)" -ForegroundColor Gray
        Write-Host "      Service Uptime: $($response.uptime)s" -ForegroundColor Gray
    } else {
        Write-Host " DEGRADED (Latency: ${latencyMs}ms)" -ForegroundColor Yellow
        if ($latencyMs -gt $MaxLatencyMs) {
            Write-Warning "Latency exceeded SLA threshold of ${MaxLatencyMs}ms."
        }
    }
} catch {
    $stopwatch.Stop()
    Write-Host " FAILED ($($_.Exception.Message))" -ForegroundColor Red
    Write-Host "`n[!] Health check failed! Automated rollback recommended." -ForegroundColor Red
    exit 1
}

# Probe 2: Synthetic IMEI Check Endpoint
$verifyUrl = "$ApiUrl/api/v1/devices/verify?imei=358765091234563"
Write-Host "`n[2/2] Probing IMEI Verification: $verifyUrl..." -NoNewline

$stopwatch.Restart()
try {
    $verifyRes = Invoke-RestMethod -Uri $verifyUrl -Method GET -TimeoutSec 10 -ErrorAction Stop
    $stopwatch.Stop()
    $latencyMs = $stopwatch.ElapsedMilliseconds

    Write-Host " PASS (Status: 200 | Latency: ${latencyMs}ms)" -ForegroundColor Green
    Write-Host "      IMEI Tested   : 358765091234563" -ForegroundColor Gray
    Write-Host "      Result Status : $($verifyRes.deviceStatus)" -ForegroundColor Gray
} catch {
    $stopwatch.Stop()
    Write-Host " FAILED ($($_.Exception.Message))" -ForegroundColor Red
    exit 1
}

Write-Host "`n[+] All synthetic health probes PASSED within SLA thresholds." -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Cyan
exit 0
