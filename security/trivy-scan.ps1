<#
.SYNOPSIS
    Scan de sécurité Trivy
#>

param(
    [string]$ImageName = "flask-api:latest",
    [string]$SeverityThreshold = "CRITICAL",
    [string]$OutputDir = ".\security\reports",
    [switch]$FailOnVuln,
    [switch]$Full
)

$ErrorActionPreference = "Continue"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ReportDir = Join-Path $OutputDir $Timestamp

# ── Couleurs ──
function Write-Step { param($msg) Write-Host "`n🔍 $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "   ✅ $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "   ⚠️  $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "   ❌ $msg" -ForegroundColor Red }

Write-Host @"
╔══════════════════════════════════════════════╗
║       🛡️  TRIVY SECURITY SCANNER            ║
╚══════════════════════════════════════════════╝
"@ -ForegroundColor Magenta

# ── Vérifier Trivy ──
if (!(Get-Command trivy -ErrorAction SilentlyContinue)) {
    Write-Err "Trivy non installé : choco install trivy -y"
    exit 1
}

Write-OK "Trivy : $(trivy --version 2>$null | Select-Object -First 1)"

# ── Créer dossier rapports ──
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
Write-OK "Rapports : $ReportDir"

# ── Compteurs ──
$criticalCount = 0
$highCount     = 0
$mediumCount   = 0

# ══════════════════════════════════════════
#  SCAN 1 : IMAGE DOCKER
# ══════════════════════════════════════════

Write-Step "SCAN 1 — Image Docker : $ImageName"

# Vérifier que l'image existe
$imageExists = docker image inspect $ImageName 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warn "Image introuvable, build en cours..."
    docker build -t $ImageName -f docker/Dockerfile .
}

# Scan console
trivy image `
    --severity "CRITICAL,HIGH,MEDIUM" `
    --ignore-unfixed `
    --no-progress `
    $ImageName

# Scan JSON
$jsonReport = Join-Path $ReportDir "image-scan.json"
trivy image `
    --severity "CRITICAL,HIGH,MEDIUM" `
    --format json `
    --output $jsonReport `
    --ignore-unfixed `
    --no-progress `
    $ImageName 2>$null

# Parser le JSON
if (Test-Path $jsonReport) {
    try {
        $vulnData = Get-Content $jsonReport -Raw | ConvertFrom-Json
        if ($vulnData.Results) {
            foreach ($result in $vulnData.Results) {
                if ($result.Vulnerabilities) {
                    foreach ($vuln in $result.Vulnerabilities) {
                        switch ($vuln.Severity) {
                            "CRITICAL" { $criticalCount++ }
                            "HIGH"     { $highCount++ }
                            "MEDIUM"   { $mediumCount++ }
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-Warn "Impossible de parser le rapport JSON"
    }
}

Write-Host "`n   📊 Résumé image :" -ForegroundColor White
Write-Host "      🔴 CRITICAL : $criticalCount" -ForegroundColor $(if ($criticalCount -gt 0) { "Red" } else { "Green" })
Write-Host "      🟠 HIGH     : $highCount"     -ForegroundColor $(if ($highCount -gt 0) { "Yellow" } else { "Green" })
Write-Host "      🟡 MEDIUM   : $mediumCount"   -ForegroundColor $(if ($mediumCount -gt 0) { "Yellow" } else { "Green" })

# ══════════════════════════════════════════
#  SCAN 2 : DOCKERFILE
# ══════════════════════════════════════════

Write-Step "SCAN 2 — Dockerfile"

if (Test-Path ".\docker\Dockerfile") {
    trivy config `
        --severity "CRITICAL,HIGH,MEDIUM" `
        --no-progress `
        .\docker\Dockerfile
    Write-OK "Scan Dockerfile terminé"
}
else {
    Write-Warn "Dockerfile introuvable"
}

# ══════════════════════════════════════════
#  SCAN 3 : FILESYSTEM (dépendances)
# ══════════════════════════════════════════

if ($Full) {
    Write-Step "SCAN 3 — Dépendances Python"

    trivy fs `
        --severity "CRITICAL,HIGH,MEDIUM" `
        --scanners vuln `
        --no-progress `
        .\app\

    Write-OK "Scan dépendances terminé"

    Write-Step "SCAN 4 — Secrets exposés"

    trivy fs `
        --scanners secret `
        --no-progress `
        .

    Write-OK "Scan secrets terminé"
}

# ══════════════════════════════════════════
#  RÉSUMÉ FINAL
# ══════════════════════════════════════════

Write-Host "`n╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           📊 RÉSUMÉ SCAN SÉCURITÉ           ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "   🔴 CRITICAL : $criticalCount" -ForegroundColor $(if ($criticalCount -gt 0) { "Red" } else { "Green" })
Write-Host "   🟠 HIGH     : $highCount"     -ForegroundColor $(if ($highCount -gt 0) { "Yellow" } else { "Green" })
Write-Host "   🟡 MEDIUM   : $mediumCount"   -ForegroundColor $(if ($mediumCount -gt 0) { "Yellow" } else { "Green" })

# ── Décision ──
$shouldFail = $false

switch ($SeverityThreshold) {
    "CRITICAL" {
        if ($criticalCount -gt 0) { $shouldFail = $true }
    }
    "HIGH" {
        if ($criticalCount -gt 0 -or $highCount -gt 0) { $shouldFail = $true }
    }
    "MEDIUM" {
        if ($criticalCount + $highCount + $mediumCount -gt 0) { $shouldFail = $true }
    }
    default {
        $shouldFail = $false
    }
}

if ($shouldFail -and $FailOnVuln) {
    Write-Host "`n❌ BUILD BLOQUÉ — Vulnérabilités $SeverityThreshold+ détectées" -ForegroundColor Red
    exit 1
}
elseif ($shouldFail) {
    Write-Host "`n⚠️  Vulnérabilités $SeverityThreshold+ détectées (non bloquant)" -ForegroundColor Yellow
    Write-Host "   Ajoutez -FailOnVuln pour bloquer le build" -ForegroundColor Yellow
}
else {
    Write-Host "`n✅ SCAN RÉUSSI — Aucune vulnérabilité $SeverityThreshold+ détectée" -ForegroundColor Green
}

# Résumé JSON
$summary = [PSCustomObject]@{
    timestamp      = $Timestamp
    image          = $ImageName
    threshold      = $SeverityThreshold
    critical_count = $criticalCount
    high_count     = $highCount
    medium_count   = $mediumCount
    passed         = (-not $shouldFail)
    reports_dir    = $ReportDir
}

$summaryPath = Join-Path $ReportDir "summary.json"
$summary | ConvertTo-Json | Out-File -FilePath $summaryPath -Encoding UTF8
Write-OK "Résumé : $summaryPath"

exit 0