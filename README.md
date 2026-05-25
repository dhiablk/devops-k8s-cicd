# k8s-cicd-project

Projet complet Kubernetes + CI/CD avec sécurité Trivy sur Windows.

## Architecture

- Flask API (3 réplicas)
- Redis cache
- PostgreSQL avec volume persistant
- Ingress NGINX pour HTTPS / TLS local
- Trivy pour scans d'image, manifestes et code
- GitHub Actions pour CI / CD

## Structure

- `app/` : code source Flask
- `docker/` : Dockerfiles et ignore
- `k8s/` : manifests Kubernetes
- `security/` : configuration Trivy et scripts de scan
- `scripts/` : scripts PowerShell d'installation, déploiement et nettoyage
- `.github/workflows/` : pipelines CI et CD

## Prérequis

- Windows 10/11
- PowerShell 7+ recommandé
- Docker Desktop
- kubectl
- minikube
- Helm
- Trivy

## Installation Windows

Exécutez en PowerShell administrateur :

```powershell
.
\scripts\setup-windows.ps1
```

## Déploiement local

```powershell
.
\scripts\deploy.ps1
```

## Nettoyage

```powershell
.
\scripts\cleanup.ps1
```

## Scan de sécurité

```powershell
.
\security\trivy-scan.ps1 -ImageName "flask-api:latest" -SeverityThreshold "HIGH" -FailOnVuln -Full
```
<img width="949" height="426" alt="image" src="https://github.com/user-attachments/assets/9ed2ef69-8a4c-4cc9-9875-cb52f9a64ad3" />
