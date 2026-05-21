IMAGE_NAME=flask-api:latest
REGISTRY=ghcr.io/your-org/flask-api
TAG=latest

.PHONY: build docker-build docker-push deploy scan clean

build:
	python -m compileall app

docker-build:
	docker build -t $(IMAGE_NAME) -f docker/Dockerfile .

docker-push:
	docker tag $(IMAGE_NAME) $(REGISTRY):$(TAG)
	docker push $(REGISTRY):$(TAG)

deploy:
	powershell -ExecutionPolicy Bypass -File scripts/deploy.ps1

scan:
	powershell -ExecutionPolicy Bypass -File security/trivy-scan.ps1 -ImageName "$(IMAGE_NAME)" -SeverityThreshold "HIGH" -FailOnVuln -Full

clean:
	powershell -ExecutionPolicy Bypass -File scripts/cleanup.ps1
