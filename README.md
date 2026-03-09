# CredPal DevOps Assessment

This repository contains a production-oriented DevOps solution for a basic Node.js web application.

## Features

- Node.js app with 3 endpoints:
  - `GET /health`
  - `GET /status`
  - `POST /process`
- Docker multi-stage build
- Non-root container user
- Redis service with Docker Compose
- GitHub Actions CI and deployment workflow
- Terraform infrastructure on AWS using:
  - VPC
  - public/private subnets
  - security groups
  - ECS Fargate
  - Application Load Balancer
  - ACM certificate for HTTPS
  - Route 53 DNS record
- Rolling deployment with ECS
- Manual approval for production through GitHub environment protection
- Logging to CloudWatch and health checks via ALB/ECS

## Application endpoints

### Health
```bash
curl http://localhost:3000/health
````

### Status

```bash
curl http://localhost:3000/status
```

### Process

```bash
curl -X POST http://localhost:3000/process \
  -H "Content-Type: application/json" \
  -d '{"job":"sample"}'
```

## Run locally

### 1. Copy env file

```bash
cp .env.example .env
```

### 2. Start with Docker Compose

```bash
docker compose up --build
```

### 3. Access the app

* App: `http://localhost:3000`
* Redis: `localhost:6379`

## Run tests

```bash
npm ci
npm test
```

## Build Docker image

```bash
docker build -t credpal-app:local .
```

## Deploy infrastructure

### Prerequisites

* AWS account
* Route 53 hosted zone
* Terraform installed
* Remote state bucket + DynamoDB lock table

### Steps

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit values
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

After apply, note these outputs:

* `ecr_repository_url`
* `ecs_cluster_name`
* `ecs_service_name`
* `ecs_task_definition_family`
* `app_url`

Store the required values as GitHub Actions secrets.

## CI/CD design

### CI pipeline

Triggered on:

* push to `main`
* pull requests to `main`

It performs:

* dependency installation
* unit tests
* image build
* image push on main

### Deployment pipeline

Triggered manually via `workflow_dispatch`.
Uses:

* GitHub protected production environment for manual approval
* ECS rolling deployment with service stability checks

## Security decisions

* No application secrets stored in code or GitHub workflow files
* Secrets are expected through GitHub Actions secrets or AWS-managed secret stores
* Container runs as non-root user
* ALB terminates TLS using ACM certificate
* Application runs in private subnets on ECS Fargate
* Security groups restrict traffic so only the ALB can reach the app
* Terraform state is intended to be stored remotely in encrypted S3 with DynamoDB locking

## Observability decisions

* Application logs to stdout/stderr
* ECS forwards container logs to CloudWatch Logs
* `/health` endpoint used for health checking
* ALB target group health check configured against `/health`

## Zero-downtime deployment

* ECS service uses rolling deployment
* `deployment_minimum_healthy_percent = 100`
* `deployment_maximum_percent = 200`
* ALB routes traffic only to healthy tasks

## Possible improvements

* Add WAF in front of ALB
* Use AWS Secrets Manager or SSM Parameter Store for runtime secrets
PORT=3000
* Add structured JSON logging
* Add CloudWatch alarms and SNS notifications
* Add autoscaling policies for ECS service
* Add Redis as ElastiCache instead of local Compose-only Redis

```

  try {
---
const port = process.env.PORT || 3000;

FROM node:20-alpine AS deps
# 6) What to say about the design
node_modules

version: "3.9"
Use this wording in the README and interview discussion:

- **Containerization:** I used a multi-stage Docker build to keep the runtime image small and secure. The container runs as a non-root user and includes a health check.
- **CI/CD:** I split CI and deployment logically. CI validates every pull request and push to main. Deployment is manual to production through a protected GitHub environment.
- **Infrastructure:** I chose ECS Fargate behind an ALB because it is simpler and more production-ready than a single EC2 instance for a small service, while still meeting the load balancer and HTTPS requirements.
- **Zero downtime:** ECS rolling deployment plus ALB health checks ensures new tasks become healthy before old tasks are drained.
- **Security:** Secrets are not committed to the repository. Runtime secrets are intended to come from GitHub Secrets or AWS-managed secret stores.

---

# 7) Submission tips

Before submitting:

1. Make sure the repo is clean and copy-paste runnable.
2. Replace placeholder values in Terraform and README.
3. Add screenshots if you want extra polish:
   - successful GitHub Action run
   - ECS service healthy
   - ALB / app response
4. Do not overcomplicate beyond what you can explain confidently.

---

# 8) Honest gaps you can mention if needed

This sample solution uses Redis only for local Compose support. In a real production deployment, Redis should be replaced with ElastiCache or another managed datastore.    
That is a reasonable and professional design decision to mention explicitly.

```

