#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Install the K8s + CI/CD + Trivy environment on Windows
.DESCRIPTION
    Installs: Docker Desktop, kubectl, minikube, Helm, Trivy, k9s
#>

param(
    [switch]$SkipDocker,
    [switch]$SkipMinikube,
    [switch]$Force
)

Set-StrictMode -Version Latest
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

function Install-Choco {
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Step "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path += ";$($env:ALLUSERSPROFILE)\\chocolatey\\bin"
    }
    else {
        Write-Info "Chocolatey already installed: $(choco --version)"
    }
}

function Install-ChocoPackage {
    param(
        [string]$Name,
        [string]$TestCommand = $Name,
        [string]$Version = ""
    )
    if (Get-Command $TestCommand -ErrorAction SilentlyContinue) {
        Write-Info "$Name already installed"
        return
    }
    Write-Step "Installing $Name..."
    $cmd = "choco install $Name -y --no-progress"
    if ($Version) { $cmd += " --version=$Version" }
    Invoke-Expression $cmd
    refreshenv 2>$null
}

$banner = @"
=== Setup K8s + CI/CD + Trivy - Windows ===
"@
Write-Host $banner -ForegroundColor Magenta

Install-Choco

if (-not $SkipDocker) {
    Install-ChocoPackage -Name "docker-desktop" -TestCommand "docker"
}

Install-ChocoPackage -Name "kubernetes-cli" -TestCommand "kubectl"

if (-not $SkipMinikube) {
    Install-ChocoPackage -Name "minikube" -TestCommand "minikube"
}

Install-ChocoPackage -Name "kubernetes-helm" -TestCommand "helm"

Write-Step "Installing Trivy..."
if (!(Get-Command trivy -ErrorAction SilentlyContinue)) {
    choco install trivy -y --no-progress
    refreshenv 2>$null
}
else {
    Write-Info "Trivy already installed: $(trivy --version)"
}

Install-ChocoPackage -Name "k9s" -TestCommand "k9s"

Write-Step "Configuring Minikube..."
$minikubeStatus = minikube status --format='{{.Host}}' 2>$null
if ($minikubeStatus -ne "Running") {
    Write-Info "Starting Minikube (driver=docker, 4 CPU, 8 GB RAM)..."
    minikube start `
        --driver=docker `
        --cpus=4 `
        --memory=8192 `
        --disk-size=40g `
        --kubernetes-version=v1.28.0 `
        --addons=ingress,metrics-server,dashboard `
        --extra-config=apiserver.enable-admission-plugins=PodSecurity
}
else {
    Write-Info "Minikube already running"
}

Write-Step "Enabling Minikube addons..."
$addons = @("ingress", "metrics-server", "dashboard", "ingress-dns")
foreach ($addon in $addons) {
    minikube addons enable $addon 2>$null
    Write-Info "Addon enabled: $addon"
}

Write-Host "`n" -NoNewline
Write-Host "=== INSTALLATION COMPLETE ===" -ForegroundColor Green

$tools = @(
    @{Name = "Docker"; Cmd = "docker --version" },
    @{Name = "kubectl"; Cmd = "kubectl version --client --short" },
    @{Name = "Minikube"; Cmd = "minikube version --short" },
    @{Name = "Helm"; Cmd = "helm version --short" },
    @{Name = "Trivy"; Cmd = "trivy --version" },
    @{Name = "k9s"; Cmd = "k9s version --short" }
)

foreach ($tool in $tools) {
    try {
        $ver = Invoke-Expression $tool.Cmd 2>$null
        Write-Host "   [OK] $($tool.Name): $ver" -ForegroundColor Green
    }
    catch {
        Write-Host "   [ERROR] $($tool.Name): Not found" -ForegroundColor Red
    }
}

Write-Host "   [INFO] Next step: .\scripts\deploy.ps1" -ForegroundColor Yellow
