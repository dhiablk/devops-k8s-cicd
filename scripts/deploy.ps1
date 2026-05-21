param(
    [switch]$SkipBuild,
    [switch]$SkipScan,
    [switch]$CleanFirst
)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "     DEPLOIEMENT K8s - Windows             " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# ── Vérifications ──
foreach ($cmd in @("docker", "minikube")) {
    if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERREUR: $cmd non trouve !" -ForegroundColor Red
        exit 1
    }
}

Write-Host "OK: docker et minikube trouves" -ForegroundColor Green

# ── Vérifier Minikube ──
$mkStatus = minikube status --format='{{.Host}}' 2>$null
if ($mkStatus -ne "Running") {
    Write-Host "Demarrage de Minikube..." -ForegroundColor Yellow
    minikube start --driver=docker --cpus=4 --memory=4096
} else {
    Write-Host "OK: Minikube deja en cours" -ForegroundColor Green
}

# ── Configurer Docker pour Minikube ──
Write-Host "Configuration Docker vers Minikube..." -ForegroundColor Cyan
& minikube -p minikube docker-env --shell powershell | Invoke-Expression

# ── Build ──
if (-not $SkipBuild) {
    Write-Host "Build de l image Docker..." -ForegroundColor Cyan
    docker build -t flask-api:latest -f docker/Dockerfile .
    Write-Host "OK: Image flask-api:latest construite" -ForegroundColor Green
}

# ── Scan Trivy ──
if (-not $SkipScan) {
    if (Get-Command trivy -ErrorAction SilentlyContinue) {
        Write-Host "Scan Trivy..." -ForegroundColor Cyan
        & .\security\trivy-scan.ps1 -ImageName "flask-api:latest"
    } else {
        Write-Host "Trivy non installe, scan ignore" -ForegroundColor Yellow
    }
}

# ── Nettoyage ──
if ($CleanFirst) {
    Write-Host "Nettoyage namespace..." -ForegroundColor Yellow
    minikube kubectl -- delete namespace flask-app --ignore-not-found=true 2>$null
    Start-Sleep -Seconds 5
}

# ── Déploiement ──
Write-Host "Deploiement Kubernetes..." -ForegroundColor Cyan

$manifests = @(
    "k8s/namespace.yaml",
    "k8s/secret.yaml",
    "k8s/configmap.yaml",
    "k8s/postgres.yaml",
    "k8s/redis.yaml",
    "k8s/app.yaml"
)

foreach ($manifest in $manifests) {
    if (Test-Path $manifest) {
        minikube kubectl -- apply -f $manifest
        Write-Host "OK: $manifest" -ForegroundColor Green
    } else {
        Write-Host "MANQUANT: $manifest" -ForegroundColor Yellow
    }
}

# ── Attendre les pods ──
Write-Host "Attente des pods..." -ForegroundColor Yellow

Write-Host "Attente postgres..." -ForegroundColor DarkGray
minikube kubectl -- wait --for=condition=ready pod -l app=postgres -n flask-app --timeout=120s

Write-Host "Attente redis..." -ForegroundColor DarkGray
minikube kubectl -- wait --for=condition=ready pod -l app=redis -n flask-app --timeout=60s

Write-Host "Attente flask-api..." -ForegroundColor DarkGray
minikube kubectl -- wait --for=condition=ready pod -l app=flask-api -n flask-app --timeout=120s

# ── Statut final ──
Write-Host ""
Write-Host "Pods :" -ForegroundColor Cyan
minikube kubectl -- get pods -n flask-app -o wide

Write-Host ""
Write-Host "Services :" -ForegroundColor Cyan
minikube kubectl -- get svc -n flask-app

# ── Test rapide ──
Write-Host "Test de l application..." -ForegroundColor Cyan

$portForwardJob = Start-Job -ScriptBlock {
    & minikube kubectl -- port-forward svc/flask-api-service 8080:80 -n flask-app
}

Start-Sleep -Seconds 8

try {
    $response = Invoke-RestMethod -Uri "http://127.0.0.1:8080/live" -TimeoutSec 10
    Write-Host "OK: Application repond - alive=$($response.alive)" -ForegroundColor Green
} catch {
    Write-Host "ATTENTION: Test echoue - $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Lancez manuellement: minikube kubectl -- port-forward svc/flask-api-service 8080:80 -n flask-app" -ForegroundColor Yellow
} finally {
    Stop-Job $portForwardJob -ErrorAction SilentlyContinue
    Remove-Job $portForwardJob -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "         DEPLOIEMENT TERMINE !             " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Pour acceder a l app :" -ForegroundColor Yellow
Write-Host "minikube kubectl -- port-forward svc/flask-api-service 8080:80 -n flask-app" -ForegroundColor White
Write-Host ""
Write-Host "Tests (dans un autre terminal) :" -ForegroundColor Yellow
Write-Host "Invoke-RestMethod -Uri 'http://127.0.0.1:8080/live'" -ForegroundColor White
Write-Host "Invoke-RestMethod -Uri 'http://127.0.0.1:8080/health'" -ForegroundColor White
Write-Host "Invoke-RestMethod -Uri 'http://127.0.0.1:8080/api/v1/tasks'" -ForegroundColor White