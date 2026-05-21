<#
.SYNOPSIS
    Port-forward pour accéder aux services depuis Windows
#>

Write-Host "🔌 Port-forwarding des services..." -ForegroundColor Cyan

Start-Process -NoNewWindow powershell -ArgumentList "kubectl port-forward svc/flask-api-service 5000:80 -n flask-app"
Write-Host "   ✅ Flask API   : http://localhost:5000" -ForegroundColor Green

Start-Process -NoNewWindow powershell -ArgumentList "kubectl port-forward svc/postgres-service 5432:5432 -n flask-app"
Write-Host "   ✅ PostgreSQL  : localhost:5432" -ForegroundColor Green

Start-Process -NoNewWindow powershell -ArgumentList "kubectl port-forward svc/redis-service 6379:6379 -n flask-app"
Write-Host "   ✅ Redis       : localhost:6379" -ForegroundColor Green

Write-Host "`n📋 Test rapide :" -ForegroundColor Yellow
Write-Host "   curl http://localhost:5000/health" -ForegroundColor White
Write-Host "   curl http://localhost:5000/api/v1/tasks" -ForegroundColor White

Write-Host "`nAppuyez sur Ctrl+C pour arrêter tous les port-forwards" -ForegroundColor DarkGray

