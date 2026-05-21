#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Test the Flask application running in Docker Compose
.DESCRIPTION
    Verifies that all services are healthy and endpoints are responding
#>

param(
    [switch]$Up,
    [switch]$Down,
    [int]$MaxRetries = 5,
    [int]$RetryDelaySeconds = 3
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param($msg)
    Write-Host "`n[STEP] $msg" -ForegroundColor Green
}

function Write-Info {
    param($msg)
    Write-Host "   [INFO] $msg" -ForegroundColor Cyan
}

function Write-Warn {
    param($msg)
    Write-Host "   [WARN] $msg" -ForegroundColor Yellow
}

function Write-Err {
    param($msg)
    Write-Host "   [ERROR] $msg" -ForegroundColor Red
}

function Test-Endpoint {
    param(
        [string]$Url,
        [string]$Name,
        [hashtable]$Headers = @{}
    )
    
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            $response = Invoke-WebRequest -Uri $Url -Headers $Headers -TimeoutSec 5 -ErrorAction Stop
            Write-Info "$Name ✅ HTTP $($response.StatusCode)"
            return $true
        }
        catch {
            $attempt++
            if ($attempt -lt $MaxRetries) {
                Write-Warn "$Name - Attempt $attempt/$MaxRetries failed, retrying in ${RetryDelaySeconds}s..."
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            else {
                Write-Err "$Name ❌ Failed after $MaxRetries attempts: $($_.Exception.Message)"
                return $false
            }
        }
    }
    return $false
}

if ($Up) {
    Write-Step "Starting Docker Compose services..."
    docker-compose up -d
    Write-Info "Waiting for services to be ready..."
    Start-Sleep -Seconds 5
}

Write-Host @"
╔══════════════════════════════════════════════╗
║     🧪 Testing Flask Application             ║
╚══════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Step "Testing endpoints..."

$endpoints = @(
    @{
        Url = "http://localhost:5000/health"
        Name = "Health Check"
        Headers = @{"Content-Type" = "application/json"}
    },
    @{
        Url = "http://localhost:5000/ready"
        Name = "Readiness Probe"
        Headers = @{"Content-Type" = "application/json"}
    },
    @{
        Url = "http://localhost:5000/api/v1/tasks"
        Name = "Tasks API"
        Headers = @{"Content-Type" = "application/json"}
    }
)

$allPassed = $true
foreach ($endpoint in $endpoints) {
    if (-not (Test-Endpoint -Url $endpoint.Url -Name $endpoint.Name -Headers $endpoint.Headers)) {
        $allPassed = $false
    }
}

Write-Step "Container status..."
docker-compose ps

if ($allPassed) {
    Write-Host "`n✅ All tests passed!" -ForegroundColor Green
}
else {
    Write-Host "`n⚠️ Some tests failed. Check logs with: docker-compose logs" -ForegroundColor Yellow
    docker-compose logs flask-app | Select-Object -Last 20
}

if ($Down) {
    Write-Step "Stopping Docker Compose services..."
    docker-compose down
    Write-Info "Services stopped"
}

exit $(if ($allPassed) { 0 } else { 1 })
