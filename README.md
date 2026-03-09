# CredPal DevOps Assessment

This repository contains a production-ready DevOps implementation for a simple Node.js web application built as part of the CredPal DevOps Engineer assessment.

The solution demonstrates:

- Containerization using a secure multi-stage Docker build
- Local orchestration using Docker Compose (App + Redis)
- Continuous Integration using GitHub Actions
- Container image publishing to GitHub Container Registry (GHCR)
- Infrastructure provisioning using Terraform on AWS
- HTTPS-enabled deployment behind an Application Load Balancer
- Zero-downtime deployment using ECS rolling updates
- Secure runtime configuration and container hardening
- Basic logging and health monitoring

---

# 1. Application Overview

The application runs on **port 3000** and exposes three endpoints:

- `GET /health`
- `GET /status`
- `POST /process`

Redis is used for lightweight state tracking during local development.

## Endpoints

### GET /health

Used for container, ECS, and load balancer health checks.

```bash
curl http://localhost:3000/health
```

---

### GET /status

Returns service status and processed request count.

```bash
curl http://localhost:3000/status
```

---

### POST /process

Accepts a JSON payload and increments a counter stored in Redis.

```bash
curl -X POST http://localhost:3000/process \
  -H "Content-Type: application/json" \
  -d '{"task":"demo"}'
```

---

# 2. How to Run the Application Locally

## Prerequisites

- Docker Desktop (WSL integration enabled if using WSL)
- Docker Compose

## Start the Application

From the project root:

```bash
docker compose up --build
```

This starts:

- Node.js application on port `3000`
- Redis on port `6379`

## Access the Application

Open in browser:

```
http://localhost:3000
```

Or test with curl:

```bash
curl http://localhost:3000/health
curl http://localhost:3000/status
```

---

# 3. How to Deploy the Application

Infrastructure is provisioned using Terraform on AWS.

## Prerequisites

- AWS account
- Terraform installed
- AWS CLI configured
- (Optional) Route 53 hosted zone for custom domain

## Step 1 – Provision Infrastructure

```bash
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
```

Terraform provisions:

- VPC
- Public and private subnets
- Security groups
- ECS Cluster (Fargate)
- ECS Service
- Application Load Balancer
- Target group
- ACM SSL certificate
- (Optional) Route 53 DNS record

## Step 2 – Deploy Application

Deployment is handled via GitHub Actions.

1. Push changes to `main`
2. Trigger the deployment workflow
3. Approve production deployment (manual approval required)
4. ECS performs rolling deployment

After deployment, access the app via:

- ALB DNS name
- Or custom HTTPS domain

Example:

```
https://your-domain.com
```

---

# 4. CI/CD Design

GitHub Actions is used for Continuous Integration and Deployment.

## CI Pipeline

Triggered on:

- Push to `main`
- Pull request to `main`

The pipeline performs:

1. Checkout code
2. Install dependencies using `npm ci`
3. Run unit tests using `npm test`
4. Build Docker image
5. Push image to GitHub Container Registry (GHCR) on push to `main`

Image format:

```
ghcr.io/<github-username>/credpal-devops-assessment
```

GHCR was chosen to avoid managing separate Docker Hub credentials and to integrate seamlessly with GitHub Actions.

## Deployment Pipeline

- Triggered manually (`workflow_dispatch`)
- Protected by GitHub `production` environment
- Requires manual approval before execution
- Updates ECS task definition with new image version

This satisfies the requirement for manual approval before production deployment.

---

# 5. Zero-Downtime Deployment Strategy

Zero downtime is achieved using:

- ECS rolling deployment
- Desired task count ≥ 2
- ALB health checks on `/health`
- Deployment settings:
  - `minimum_healthy_percent = 100`
  - `maximum_percent = 200`

Deployment flow:

1. New task version is launched.
2. ALB health checks validate new tasks.
3. Traffic is routed only to healthy tasks.
4. Old tasks are drained and stopped.

Users never experience downtime during deployment.

---

# 6. Security Decisions

## Secrets Management

- No application secrets are committed to the repository.
- Runtime secrets are intended to be stored in:
  - AWS Secrets Manager, or
  - AWS SSM Parameter Store
- Secrets are injected into ECS task definitions at runtime.
- No long-lived AWS credentials are stored in code.

## Container Security

- Multi-stage Docker build reduces attack surface.
- Application runs as a **non-root user** inside the container.
- Only required runtime files are included in final image.
- Docker HEALTHCHECK is implemented.

## Network Security

- Only ALB is publicly accessible (ports 80/443).
- ECS tasks accept traffic only from ALB security group.
- No direct public access to containers.

## HTTPS

- TLS termination handled by Application Load Balancer.
- SSL certificate provisioned via AWS Certificate Manager (ACM).

---

# 7. Infrastructure Design Decisions

## Why ECS Fargate?

ECS Fargate was selected instead of EC2 because:

- No server management required
- Built-in rolling deployments
- Simplified scaling
- Cleaner production-ready container orchestration

## Why Application Load Balancer?

- Enables HTTPS
- Provides health checks
- Supports zero-downtime routing
- Distributes traffic across tasks

## Why Multi-Stage Docker Build?

- Smaller runtime image
- Clear separation of build and runtime layers
- Reduced security exposure

---

# 8. Observability

## Logging

The application logs:

- Server startup events
- HTTP request logs (via Morgan)
- Errors and Redis connectivity issues

Logs are written to stdout/stderr.

In ECS, logs are forwarded to CloudWatch Logs.

## Health Monitoring

Health validation exists at multiple layers:

- Application endpoint `/health`
- Docker container HEALTHCHECK
- ALB target group health check
- ECS service health validation

---

# 9. Local vs Production Architecture

## Local Development

- Docker Compose
- Node.js container
- Redis container

## Production

- ECS Fargate
- Application Load Balancer (HTTPS)
- ACM certificate
- Secrets Manager for runtime secrets

Redis is used locally for simplicity.  
In production, a managed service such as Amazon ElastiCache would be recommended if persistence or scaling were required.

---

# 10. Summary

This implementation demonstrates:

- Secure containerization
- Automated CI/CD
- Infrastructure as Code using Terraform
- HTTPS-enabled cloud deployment
- Rolling, zero-downtime deployments
- Secure secret handling practices
- Basic logging and health monitoring

The solution focuses on clarity, production readiness, and alignment with modern DevOps best practices while keeping the application intentionally simple.
