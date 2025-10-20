.PHONY: help install dev-setup test lint format clean docker-build docker-run deploy-cf deploy-tf check-aws

# Variables
PROJECT_NAME ?= fastapi-app
ENVIRONMENT ?= production
AWS_REGION ?= us-east-1
IMAGE_TAG ?= latest

help:
	@echo "FastAPI AWS Deployment - Available Commands"
	@echo "==========================================="
	@echo ""
	@echo "Local Development:"
	@echo "  make install        - Install Python dependencies"
	@echo "  make dev-setup      - Setup local development environment"
	@echo "  make test           - Run tests"
	@echo "  make lint           - Run linters"
	@echo "  make format         - Format code"
	@echo "  make clean          - Clean temporary files"
	@echo ""
	@echo "Docker:"
	@echo "  make docker-build   - Build Docker image"
	@echo "  make docker-run     - Run Docker container locally"
	@echo "  make docker-stop    - Stop local Docker containers"
	@echo ""
	@echo "AWS Deployment:"
	@echo "  make check-aws      - Verify AWS CLI configuration"
	@echo "  make build-push     - Build and push image to ECR"
	@echo "  make deploy-cf      - Deploy with CloudFormation"
	@echo "  make deploy-tf      - Deploy with Terraform"
	@echo "  make deploy-eb      - Deploy with Elastic Beanstalk"
	@echo ""
	@echo "Infrastructure Management:"
	@echo "  make tf-init        - Initialize Terraform"
	@echo "  make tf-plan        - Plan Terraform changes"
	@echo "  make tf-apply       - Apply Terraform changes"
	@echo "  make tf-destroy     - Destroy Terraform infrastructure"
	@echo ""
	@echo "Utilities:"
	@echo "  make logs           - Tail CloudWatch logs"
	@echo "  make status         - Check deployment status"
	@echo "  make migrate        - Run database migrations on AWS"

# Local Development
install:
	pip install --upgrade pip
	pip install -r requirements.txt

dev-setup:
	cp .env.example .env
	docker compose up db -d
	sleep 5
	alembic upgrade head
	@echo "Development environment ready!"

test:
	pytest tests/ -v --cov=app --cov-report=term-missing

lint:
	ruff check app/
	mypy app/

format:
	black app/
	ruff check --fix app/

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type d -name ".pytest_cache" -exec rm -rf {} +
	find . -type d -name ".mypy_cache" -exec rm -rf {} +
	find . -type d -name "*.egg-info" -exec rm -rf {} +

# Docker
docker-build:
	docker build -t $(PROJECT_NAME):$(IMAGE_TAG) .

docker-run:
	docker compose up --build

docker-stop:
	docker compose down -v

# AWS Verification
check-aws:
	@echo "Checking AWS CLI configuration..."
	@aws sts get-caller-identity
	@echo ""
	@echo "AWS Account ID: $$(aws sts get-caller-identity --query Account --output text)"
	@echo "AWS Region: $(AWS_REGION)"

# Build and Push to ECR
build-push: check-aws
	@echo "Building and pushing Docker image to ECR..."
	export PROJECT_NAME=$(PROJECT_NAME) && \
	export ENVIRONMENT=$(ENVIRONMENT) && \
	export AWS_REGION=$(AWS_REGION) && \
	export IMAGE_TAG=$(IMAGE_TAG) && \
	bash scripts/build-and-push-ecr.sh

# CloudFormation Deployment
deploy-cf: check-aws
	@if [ -z "$(DB_PASSWORD)" ]; then \
		echo "Error: DB_PASSWORD is required"; \
		echo "Usage: make deploy-cf DB_PASSWORD=YourPassword CONTAINER_IMAGE=your-image-uri"; \
		exit 1; \
	fi
	@if [ -z "$(CONTAINER_IMAGE)" ]; then \
		echo "Error: CONTAINER_IMAGE is required"; \
		echo "Usage: make deploy-cf DB_PASSWORD=YourPassword CONTAINER_IMAGE=your-image-uri"; \
		exit 1; \
	fi
	export PROJECT_NAME=$(PROJECT_NAME) && \
	export ENVIRONMENT=$(ENVIRONMENT) && \
	export AWS_REGION=$(AWS_REGION) && \
	export DB_PASSWORD=$(DB_PASSWORD) && \
	export CONTAINER_IMAGE=$(CONTAINER_IMAGE) && \
	bash scripts/deploy-cloudformation.sh

# Terraform Deployment
tf-init:
	cd infra/aws/terraform && terraform init

tf-plan:
	cd infra/aws/terraform && terraform plan

tf-apply:
	cd infra/aws/terraform && terraform apply

tf-destroy:
	cd infra/aws/terraform && terraform destroy

deploy-tf: tf-init
	bash scripts/deploy-terraform.sh

# Elastic Beanstalk
deploy-eb:
	@if ! command -v eb &> /dev/null; then \
		echo "EB CLI not found. Installing..."; \
		pip install awsebcli; \
	fi
	eb init -p docker $(PROJECT_NAME) --region $(AWS_REGION) || true
	eb create $(PROJECT_NAME)-$(ENVIRONMENT) --instance-type t3.small || true
	eb deploy

# Utilities
logs:
	aws logs tail /ecs/$(PROJECT_NAME)-$(ENVIRONMENT) --follow --region $(AWS_REGION)

status:
	@echo "Checking ECS service status..."
	@aws ecs describe-services \
		--cluster $(PROJECT_NAME)-$(ENVIRONMENT)-cluster \
		--services $(PROJECT_NAME)-$(ENVIRONMENT)-service \
		--region $(AWS_REGION) \
		--query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' \
		--output table

migrate:
	@echo "Running database migrations on ECS..."
	$(eval TASK_ARN := $(shell aws ecs list-tasks \
		--cluster $(PROJECT_NAME)-$(ENVIRONMENT)-cluster \
		--service-name $(PROJECT_NAME)-$(ENVIRONMENT)-service \
		--region $(AWS_REGION) \
		--query 'taskArns[0]' \
		--output text))
	aws ecs execute-command \
		--cluster $(PROJECT_NAME)-$(ENVIRONMENT)-cluster \
		--task $(TASK_ARN) \
		--container $(PROJECT_NAME)-container \
		--interactive \
		--command "alembic upgrade head" \
		--region $(AWS_REGION)

# Quick deployment (build + push + deploy)
quick-deploy-cf: build-push
	$(eval IMAGE_URI := $(shell aws ecr describe-repositories \
		--repository-names $(PROJECT_NAME)-$(ENVIRONMENT) \
		--region $(AWS_REGION) \
		--query 'repositories[0].repositoryUri' \
		--output text):$(IMAGE_TAG))
	@echo "Image URI: $(IMAGE_URI)"
	@read -p "Enter database password: " db_pass; \
	make deploy-cf DB_PASSWORD=$$db_pass CONTAINER_IMAGE=$(IMAGE_URI)

quick-deploy-tf: build-push deploy-tf
