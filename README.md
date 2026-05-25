
# 🚀 DevOps K8s CI/CD Project

> Projet complet DevOps : Flask API conteneurisée, déployée sur Kubernetes avec CI/CD automatisé, scan de sécurité Trivy et monitoring Prometheus/Grafana.

[![CI Pipeline](https://github.com/dhiablk/devops-k8s-cicd/actions/workflows/ci.yaml/badge.svg)](https://github.com/dhiablk/devops-k8s-cicd/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Python](https://img.shields.io/badge/python-3.12-blue)
![Docker](https://img.shields.io/badge/docker-ready-blue)
![Kubernetes](https://img.shields.io/badge/kubernetes-1.28-blue)

## 📋 Table des matières

- [Architecture](#architecture)
- [Fonctionnalités](#fonctionnalités)
- [Stack technique](#stack-technique)
- [Prérequis](#prérequis)
- [Installation rapide](#installation-rapide)
- [Tests](#tests)
- [Déploiement Kubernetes](#déploiement-kubernetes)
- [CI/CD](#cicd)
- [Sécurité](#sécurité)
- [Monitoring](#monitoring)
- [API Endpoints](#api-endpoints)
- [Structure du projet](#structure-du-projet)

---

## 🏗️ Architecture
┌───────────────────────────────────────────────────────────┐
│ UTILISATEUR │
└──────────────────────────┬────────────────────────────────┘
│
┌──────────▼──────────┐
│ Ingress NGINX │
└──────────┬──────────┘
│
┌──────────▼──────────┐
│ Flask API (x2) │ ◄── HPA (autoscaling)
└─────┬──────────┬────┘
│ │
┌───────▼──┐ ┌────▼─────┐
│PostgreSQL│ │ Redis │
│ (PVC) │ │ (cache) │
└──────────┘ └──────────┘
│ │
┌───────▼──────────▼──────┐
│ Prometheus + Grafana │
└─────────────────────────┘

text


---

## ✨ Fonctionnalités

### Application
- ✅ API REST CRUD pour gestion de tâches
- ✅ Cache Redis pour optimisation
- ✅ PostgreSQL avec persistance
- ✅ Health checks (`/live`, `/ready`, `/health`)
- ✅ Métriques Prometheus exposées

### DevOps
- ✅ Multi-stage Dockerfile optimisé
- ✅ Docker Compose pour dev local
- ✅ Manifestes Kubernetes complets
- ✅ Pipeline CI/CD GitHub Actions
- ✅ Scan de sécurité Trivy (image, K8s, deps, secrets)
- ✅ Auto-scaling horizontal (HPA)
- ✅ Network Policies (zero-trust)
- ✅ RBAC + ServiceAccounts
- ✅ Monitoring Prometheus + Grafana

---

## 🛠️ Stack technique

| Catégorie       | Technologies                                       |
|-----------------|----------------------------------------------------|
| **Backend**     | Python 3.12, Flask 3.0, SQLAlchemy                |
| **Base de données** | PostgreSQL 16, Redis 7                         |
| **Conteneurs**  | Docker, Docker Compose                            |
| **Orchestration** | Kubernetes 1.28, Minikube                       |
| **CI/CD**       | GitHub Actions, GHCR                              |
| **Sécurité**    | Trivy, NetworkPolicies, RBAC                      |
| **Monitoring**  | Prometheus, Grafana                               |

---

## 📦 Prérequis

- Windows 10/11 ou Linux/macOS
- Docker Desktop
- Minikube
- kubectl
- Git
- (Optionnel) Chocolatey pour Windows

### Installation automatique Windows

```powershell
.\scripts\setup-windows.ps1
🚀 Installation rapide
1. Cloner le projet
Bash

git clone https://github.com/dhiablk/devops-k8s-cicd.git
cd devops-k8s-cicd
2. Lancer avec Docker Compose (dev local)
Bash

docker-compose up -d
3. Tester
PowerShell

Invoke-RestMethod -Uri "http://localhost:5000/live"
Invoke-RestMethod -Uri "http://localhost:5000/health"
🧪 Tests
Bash

cd app
pip install -r requirements.txt
TESTING=true python -m pytest tests/ -v --cov=.
☸️ Déploiement Kubernetes
PowerShell

# Tout en une commande
.\scripts\deploy.ps1

# Ou manuellement
minikube start --driver=docker --cpus=4 --memory=4096
& minikube -p minikube docker-env --shell powershell | Invoke-Expression
docker build -t flask-api:latest -f docker/Dockerfile .

minikube kubectl -- apply -f k8s/namespace.yaml
minikube kubectl -- apply -f k8s/secret.yaml
minikube kubectl -- apply -f k8s/configmap.yaml
minikube kubectl -- apply -f k8s/postgres.yaml
minikube kubectl -- apply -f k8s/redis.yaml
minikube kubectl -- apply -f k8s/app.yaml

# Accès
minikube kubectl -- port-forward svc/flask-api-service 8080:80 -n flask-app
🔄 CI/CD
Pipeline déclenché à chaque push sur main :

text

┌──────────┐   ┌────────┐   ┌────────────┐
│  Tests   │──▶│ Build  │──▶│ Trivy Scan │
└──────────┘   └────────┘   └────────────┘
Jobs
Job	Description
test	Tests pytest + coverage
build	Build + push image sur GHCR
security	Scan Trivy (image, Dockerfile, K8s, deps)
🛡️ Sécurité
Trivy scans
PowerShell

.\security\trivy-scan.ps1 -ImageName "flask-api:latest" -Full
Couvre :

Vulnérabilités OS et librairies
Misconfigurations Dockerfile
Misconfigurations Kubernetes
Dépendances Python
Secrets exposés
Kubernetes
🔒 NetworkPolicies (deny-all + allow-list)
🔒 RBAC avec ServiceAccounts dédiés
🔒 securityContext (non-root, read-only FS)
🔒 Secrets Kubernetes (à migrer vers Vault en prod)
📊 Monitoring
Déployer Prometheus + Grafana
PowerShell

.\scripts\deploy-monitoring.ps1
Accès
Service	URL	Login
Prometheus	http://127.0.0.1:9090	-
Grafana	http://127.0.0.1:3000	admin/admin123
Métriques disponibles
flask_http_request_duration_seconds — Latence HTTP
tasks_created_total — Compteur de tâches créées
kube_pod_status_phase — Statut des pods
CPU, RAM, disque par pod
🌐 API Endpoints
Health
Méthode	Endpoint	Description
GET	/live	Liveness probe
GET	/ready	Readiness probe
GET	/health	État global (DB + Redis + system)
GET	/metrics	Métriques Prometheus
Tasks
Méthode	Endpoint	Description
GET	/api/v1/tasks	Lister les tâches
POST	/api/v1/tasks	Créer une tâche
GET	/api/v1/tasks/<id>	Récupérer une tâche
PUT	/api/v1/tasks/<id>	Mettre à jour
DELETE	/api/v1/tasks/<id>	Supprimer
GET	/api/v1/stats	Statistiques globales
Exemple
PowerShell

Invoke-RestMethod `
    -Method POST `
    -Uri "http://127.0.0.1:8080/api/v1/tasks" `
    -ContentType "application/json" `
    -Body ''{"title":"Apprendre K8s","priority":"high"}''
📁 Structure du projet
text

devops-k8s-cicd/
├── app/                          # Application Flask
│   ├── main.py                   # Point d''entrée
│   ├── requirements.txt          # Dépendances
│   └── tests/                    # Tests unitaires
├── docker/
│   ├── Dockerfile                # Image multi-stage
│   └── entrypoint.sh             # Script de démarrage
├── k8s/                          # Manifestes Kubernetes
│   ├── namespace.yaml
│   ├── secret.yaml
│   ├── configmap.yaml
│   ├── postgres.yaml
│   ├── redis.yaml
│   ├── app.yaml
│   ├── networkpolicy.yaml
│   ├── rbac.yaml
│   └── monitoring/               # Prometheus + Grafana
├── scripts/                      # Scripts PowerShell
│   ├── setup-windows.ps1
│   ├── deploy.ps1
│   └── deploy-monitoring.ps1
├── security/
│   └── trivy-scan.ps1            # Scan local Trivy
├── .github/
│   └── workflows/
│       ├── ci.yaml               # Pipeline CI
│       └── cd.yaml               # Pipeline CD
├── docker-compose.yaml           # Dev local
└── README.md


🤝 Contribution
Les PRs sont les bienvenues ! Pour les changements majeurs, ouvrez d''abord une issue.

📄 License
MIT © 2026 dhiablk

👤 Auteur
Dhia BK

GitHub: @dhiablk
⭐ Si ce projet vous a aidé, mettez une étoile !
'@ | Out-File -FilePath "README.md" -Encoding UTF8

text


---

# 🚀 Commandes finales

```powershell
cd C:\Users\dhia\Desktop\devops

# 1. Push monitoring + README
git add .
git commit -m "feat: add monitoring Prometheus/Grafana + complete README"
git push origin main

# 2. Déployer monitoring
.\scripts\deploy-monitoring.ps1
