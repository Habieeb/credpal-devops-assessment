# CredPal DevOps Assessment

This repository contains a production-ready DevOps implementation for a simple Node.js web application built as part of the CredPal DevOps Engineer assessment.

The solution demonstrates:

- Secure containerization using a multi-stage Docker build  
- Local orchestration using Docker Compose (Application + Redis)  
- Continuous Integration using GitHub Actions  
- Container image publishing to GitHub Container Registry (GHCR)  
- Infrastructure provisioning using Terraform on AWS  
- HTTPS-enabled deployment behind an Application Load Balancer (ALB)  
- Zero-downtime deployment using EC2 Auto Scaling rolling instance refresh  
- Manual approval before production deployment  
- Secure container hardening and runtime configuration  
- Basic logging and health monitoring  

---

# 1. Application Overview

The application runs on **port 3000** and exposes three endpoints:

- `GET /health`
- `GET /status`
- `POST /process`

Redis is used for request state tracking. In local development it runs through Docker Compose, while in production the application connects to Amazon ElastiCache Redis.

## Endpoints

### GET /health

Used for container and load balancer health checks.

```bash
curl http://localhost:3000/health
```

Returns application health and validates Redis connectivity.

---

### GET /status

Returns service uptime and processed request count.

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

- Docker Desktop (with WSL integration if using WSL)
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

Or test via curl:

```bash
curl http://localhost:3000/health
curl http://localhost:3000/status
```

---

# 3. Containerization Design

The Dockerfile uses a **multi-stage build**:

- `deps` stage – installs production dependencies  
- `builder` stage – installs dev dependencies and runs tests  
- `runtime` stage – contains only production code  

Security best practices implemented:

- Runs as a **non-root user**
- Minimal runtime image
- Explicit `HEALTHCHECK`
- Dev dependencies excluded from runtime image

The container exposes port 3000 and includes a Docker `HEALTHCHECK` that verifies the `/health` endpoint.

---

# 4. CI/CD Design

GitHub Actions is used for Continuous Integration and Deployment.

## CI Pipeline

Triggered on:

- Push to `main`
- Pull request to `main`

Pipeline steps:

1. Checkout repository  
2. Install dependencies using `npm ci`  
3. Run unit tests (`npm test`)  
4. Build Docker image  
5. Push image to GitHub Container Registry (GHCR) on push to `main`  

Image format:

```
ghcr.io/<github-username>/credpal-devops-assessment
```

GHCR was selected because:

- Native integration with GitHub Actions  
- No need for separate Docker Hub credentials  
- Simplified authentication model  

## Deployment Pipeline

Deployment is handled by a separate GitHub Actions workflow:

- Triggered manually (`workflow_dispatch`)
- Uses GitHub `production` environment
- Requires manual approval before execution
- Runs Terraform to apply infrastructure changes

This satisfies the requirement for controlled production deployment with manual approval.

---

# 5. Infrastructure Architecture (Terraform on AWS)

Infrastructure is provisioned using Terraform.

## Provisioned Components

- VPC
- Public and private subnets
- Internet Gateway
- NAT Gateway (for private subnet outbound access)
- Security Groups
- EC2 Launch Template
- Auto Scaling Group (ASG)
- Application Load Balancer (ALB)
- Target Group
- ACM SSL certificate
- Amazon ElastiCache Redis

## Architecture Overview

- ALB runs in **public subnets**
- EC2 instances run in **private subnets**
- Amazon ElastiCache Redis runs in **private subnets**
- Only ALB is publicly accessible
- EC2 instances pull container images from GHCR
- Docker runs the application container on port 3000
- The application connects to ElastiCache Redis using the Redis endpoint
- ALB forwards HTTPS traffic to EC2 instances

This design provides HTTPS termination, shared Redis state across instances, and network isolation between public and private application components.

---

# 6. How to Deploy the Application

## Prerequisites

- AWS account  
- AWS CLI installed and configured  
- Terraform installed  

## Step 1 – Provision Infrastructure

```bash
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
```

Terraform provisions the VPC, networking, security groups, EC2 Auto Scaling infrastructure, ALB, ACM certificate, and Amazon ElastiCache Redis.
The application instances are configured with the ElastiCache Redis endpoint through environment variables during instance startup.
## Step 2 – Validate ACM Certificate

If DNS is managed externally (e.g., Squarespace):

1. Copy the ACM DNS validation CNAME values from Terraform output.
2. Create the CNAME record in your DNS provider.
3. Wait for ACM status to become **Issued**.

## Step 3 – Point Domain to ALB

Create a CNAME record in your DNS provider:

- Host: `credpal`
- Value: `<alb_dns_name>`

After DNS propagation, the application will be accessible at:

```
https://credpal.sydatrix.com
```

---

# 7. Zero-Downtime Deployment Strategy

Zero downtime is achieved using:

- Auto Scaling Group rolling instance refresh  
- Desired capacity ≥ 2 instances  
- ALB health checks on `/health`  
- Rolling update strategy  

Deployment flow:

1. Launch template is updated (e.g., new image version).  
2. ASG launches new EC2 instances.  
3. ALB validates new instances via `/health`.  
4. Traffic shifts only to healthy instances.  
5. Old instances are terminated once replacements are healthy.  

Users experience no downtime during deployments.

---

# 8. Manual Approval for Production Deployment

The deployment workflow uses GitHub’s protected `production` environment.

Environment protection rules:

- Require manual approval before deployment  
- Prevent automatic production changes  

When the deployment workflow is triggered, it pauses until approval is granted.

This satisfies the requirement for manual production approval.

---

# 9. Security Decisions

- The infrastructure uses layered network security through VPC subnet separation and security groups. The ALB is publicly accessible on ports 80 and 443, while EC2 instances are isolated in private subnets and only accept application traffic from the ALB security group. Additional services such as AWS WAF or GuardDuty could be added as future enhancements, but were not required for this assessment.

## Secrets Management

- No secrets are committed to the repository.    
- In a production environment, application secrets would be stored in:
  - AWS Secrets Manager  
  - AWS SSM Parameter Store  

## Network Security

- Only ALB exposes ports 80 and 443 publicly.
- EC2 instances accept traffic only from the ALB security group.
- Amazon ElastiCache Redis accepts traffic only from the EC2 application security group on port 6379.
- EC2 instances and Redis reside in private subnets.

## Container Security

- Non-root user inside container  
- Multi-stage build reduces attack surface  
- Dev dependencies excluded from runtime image  
- Docker `HEALTHCHECK` implemented  

## HTTPS

- TLS termination handled by ALB  
- Certificate provisioned using AWS Certificate Manager (ACM)  

---

# 10. Observability

## Logging

The application logs:

- HTTP requests (via Morgan)  
- Startup events  
- Error conditions  

Logs are written to stdout/stderr.

On EC2, Docker forwards logs to system logs. In a production-grade system, logs would typically be forwarded to CloudWatch.

## Health Monitoring

Health validation exists at multiple layers:

- `/health` endpoint  
- Docker `HEALTHCHECK`  
- ALB target group health check  
- ASG health evaluation  

Unhealthy instances are automatically replaced by the Auto Scaling Group.

---

# 11. Local vs Production Architecture

## Local Development

- Docker Compose
- Node.js container
- Redis container

## Production

- EC2 Auto Scaling Group
- Launch Template
- Application Load Balancer (HTTPS)
- ACM certificate
- Amazon ElastiCache Redis
- Rolling instance refresh

In local development, Redis runs as a Docker Compose service alongside the application. In production, the application connects to a shared Amazon ElastiCache Redis instance so that request state is consistent across multiple EC2 instances behind the load balancer.

---

# 12. Summary

This implementation demonstrates:

- Secure containerization  
- Automated CI/CD pipeline  
- Infrastructure as Code using Terraform  
- HTTPS-enabled cloud deployment  
- Zero-downtime rolling deployments  
- Manual production approval  
- Secure secret handling practices  
- Basic logging and health monitoring  

The solution focuses on clarity, operational correctness, and production readiness while keeping the application intentionally simple. Local development uses Docker Compose with Redis, while production uses Amazon ElastiCache Redis to provide shared state across multiple EC2 instances.
