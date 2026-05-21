<#
.SYNOPSIS
    Nettoyage complet du projet K8s
#>

param([switch]$All)

Write-Host "🗑️ Nettoyage..." -ForegroundColor Yellow

kubectl delete namespace flask-app --ignore-not-found=true
kubectl delete pv postgres-pv --ignore-not-found=true
Write-Host "   ✅ Namespace flask-app supprimé" -ForegroundColor Green

if ($All) {
    Write-Host "   🐳 Suppression des images Docker..." -ForegroundColor Yellow
    docker rmi flask-api:latest -f 2>$null
    
    Write-Host "   💾 Arrêt de Minikube..." -ForegroundColor Yellow
    minikube stop
    
    Write-Host "   ✅ Nettoyage complet terminé" -ForegroundColor Green
}
