# End-to-End DevSecOps Project

An end-to-end DevSecOps implementation for a Node.js website, using GitLab CI/CD to test, analyze, containerize, scan, and deploy the application to Amazon EKS. Terraform provisions the AWS infrastructure, while Kubernetes manifests configure the application and monitoring alerts.

**Repository:** https://github.com/msheshta/end-to-end-devsecops-project

## Project Highlights

- GitLab CI/CD pipeline with test, quality, build, security, and deployment stages.
- Node.js application with health and Prometheus metrics endpoints.
- Docker image build and push to Docker Hub using a pipeline-specific image tag.
- SonarQube code analysis and Trivy container-image scanning.
- Terraform configuration for an Amazon EKS cluster and managed worker node group.
- Kubernetes Deployment and ClusterIP Service.
- Prometheus alert rules and an Alertmanager email receiver configuration.

## Technology Stack

| Area | Tools |
|---|---|
| Application | Node.js, npm, HTML/CSS/JavaScript static assets |
| CI/CD | GitLab CI/CD, GitLab Runner |
| Containerization | Docker, Docker-in-Docker |
| Code quality | SonarQube Scanner |
| Container security | Trivy |
| Cloud and IaC | AWS, Amazon EKS, Terraform |
| Container orchestration | Kubernetes, `kubectl` |
| Monitoring and alerting | Prometheus, Prometheus Operator resources, Alertmanager |

## Architecture and Workflow

The repository implements the following delivery flow:

1. **Test** — Run the Node.js test suite using `npm test`.
2. **Code quality** — Run SonarQube Scanner.
3. **Build and publish** — Build the Docker image and push it to Docker Hub. The image tag uses GitLab's `CI_PIPELINE_IID`.
4. **Security scan** — Run Trivy against the published image and fail the job if a CRITICAL vulnerability is detected.
5. **Deploy** — Update the Kubernetes deployment manifest with the built image, apply the application and monitoring manifests, and wait for the deployment rollout.

The SonarQube job is currently configured with `allow_failure: true`, so a failure in that job does not by itself block the pipeline. Review this setting if your intended policy is to enforce a quality gate.

## Repository Structure

```text
.
├── k8s/
│   ├── app/                 # Application Deployment and Service
│   └── monitoring/          # Prometheus rule and Alertmanager configuration
├── public/                  # Static website assets
├── src/
│   └── server.js            # Node.js HTTP server, health endpoint, metrics
├── terraform/
│   ├── main.tf              # AWS networking, IAM, EKS cluster and node group
│   ├── variables.tf         # Terraform input variables
│   └── outputs.tf            # Cluster outputs and kubeconfig command
├── test/                    # Application tests
├── .dockerignore
├── .gitignore
├── .gitlab-ci.yml            # CI/CD pipeline
├── Dockerfile
├── package.json
├── package-lock.json
└── sonar-project.properties
```

## Prerequisites

To run the application locally:

- Node.js 20 or later
- npm
- Git

To run the complete CI/CD and deployment workflow, also configure:

- A GitLab project and compatible GitLab Runner
- Docker-in-Docker support for the image build job
- A Docker Hub account and repository
- A reachable SonarQube instance
- Trivy (provided by the pipeline's Trivy job image)
- AWS credentials with permissions for the Terraform resources and EKS deployment
- Terraform and AWS CLI for provisioning and cluster access
- `kubectl`
- An EKS cluster and a monitoring stack compatible with the Prometheus Operator resources

## Run Locally

### 1. Clone the repository

```bash
git clone https://github.com/msheshta/end-to-end-devsecops-project.git
cd end-to-end-devsecops-project
```

### 2. Install dependencies

```bash
npm install
```

### 3. Start the application

```bash
npm start
```

The server listens on port `3000` by default. You can override the port with the `PORT` environment variable.

```bash
PORT=3001 npm start
```

### 4. Check the health endpoint

```bash
curl http://localhost:3000/healthz
```

Expected response:

```json
{"status":"ok"}
```

### 5. Check Prometheus metrics

```bash
curl http://localhost:3000/metrics
```

The application exposes request-count metrics by route through `devops_project_http_requests_total` and an uptime gauge through `devops_project_uptime_seconds`.

## Tests

Run the test suite:

```bash
npm test
```

Run tests with Node.js test coverage:

```bash
npm run test:coverage
```

The package scripts use Node.js's built-in test runner. The GitLab pipeline's test job currently runs `npm test`.

## Docker

The repository's Dockerfile uses `node:24-alpine3.22`, sets `NODE_ENV=production`, copies the application source and static assets, switches to the non-root `node` user, exposes port `3000`, and starts `src/server.js`.

Build and run the image locally:

```bash
docker build -t end-to-end-devsecops-project:local .
docker run --rm -p 3000:3000 end-to-end-devsecops-project:local
```

Then visit `http://localhost:3000` or check `/healthz`.

## GitLab CI/CD Configuration

The pipeline stages defined in `.gitlab-ci.yml` are:

| Stage | Job | Purpose |
|---|---|---|
| `test` | `install_job` | Runs `npm test` in a Node.js 20 Alpine image |
| `quality` | `sonarqube_scan` | Runs SonarQube Scanner |
| `build` | `build_and_push_image` | Builds and pushes the Docker image |
| `security` | `trivy_image_scan` | Fails on CRITICAL image vulnerabilities |
| `deploy` | `deploy_to eks` | Applies Kubernetes resources to EKS and checks rollout status |

### Required CI/CD variables

Configure these values in **GitLab → Settings → CI/CD → Variables**. Use masked/protected settings where appropriate and never commit secret values.

| Variable | Purpose |
|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub username used for login and image naming |
| `DOCKERHUB_TOKEN` | Docker Hub token used to push the image |
| `SONAR_HOST_URL` | URL of the SonarQube server |
| `SONAR_TOKEN` | SonarQube authentication token, if required by the server/project configuration |
| `AWS_ACCESS_KEY_ID` | AWS access key for the deployment job, if using static IAM credentials |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for the deployment job, if using static IAM credentials |
| `AWS_REGION` | AWS region used by the EKS deployment command |
| `EKS_CLUSTER_NAME` | Name of the target EKS cluster |

The AWS variables must be supplied using your chosen authentication approach. Prefer short-lived credentials or role-based federation when available rather than long-lived access keys. The Terraform variables `aws_region`, `cluster_name`, `node_instance_type`, and `desired_nodes` are defined separately in `terraform/variables.tf`.

The pipeline creates image names in this format:

```text
$DOCKERHUB_USERNAME/end-to-end-devsecops-project:$CI_PIPELINE_IID
```

## Security Scanning and Code Quality

### SonarQube

The pipeline uses `sonarsource/sonar-scanner-cli:11` and reads `SONAR_HOST_URL`. The repository's `sonar-project.properties` defines a project key and enables waiting for the quality gate result. However, the CI job is marked `allow_failure: true`; change this only if you want quality analysis failures to block delivery.

### Trivy

The Trivy job scans the published image using:

```bash
trivy image --exit-code 1 --severity CRITICAL "$IMAGE_NAME"
```

The job fails when Trivy reports CRITICAL vulnerabilities. Review scan results and update affected base images or dependencies as appropriate.

## AWS Infrastructure with Terraform

The Terraform configuration in `terraform/` defines:

- An AWS VPC with CIDR `10.40.0.0/16`
- Two public subnets across two available Availability Zones
- An Internet Gateway and public route table
- IAM roles and policy attachments for the EKS cluster and worker nodes
- An Amazon EKS cluster and managed node group

Defaults in `terraform/variables.tf`:

| Variable | Default |
|---|---|
| `aws_region` | `us-east-1` |
| `cluster_name` | `end-to-end-devops-eks` |
| `node_instance_type` | `t3.medium` |
| `desired_nodes` | `2` |

The node group's configured scaling limits are 1 minimum and 3 maximum nodes. The cluster configuration enables public endpoint access and disables private endpoint access. Review the networking and endpoint settings against your security requirements before using this configuration beyond a learning environment.

### Provision infrastructure

Run these commands from the Terraform directory after configuring AWS credentials:

```bash
cd terraform
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Review the plan and expected AWS charges before approving `terraform apply`. To remove resources created by this configuration when they are no longer needed:

```bash
terraform destroy
```

Use `terraform destroy` only when you intend to remove the infrastructure managed by this configuration and have checked for dependent resources and data.

### Configure kubectl

The Terraform outputs include a cluster connection command. For the default cluster and region, it is equivalent to:

```bash
aws eks update-kubeconfig --name end-to-end-devops-eks --region us-east-1
kubectl get nodes
```

If you override the Terraform variables, use the actual output values rather than the defaults above.

## Kubernetes Deployment

The application manifests define:

- Namespace: `devops-project`
- Deployment: `end-to-end-devops-project`
- Replicas: `2`
- Container port: `3000`
- Service: `ClusterIP`, exposing port `80` to the application's named HTTP port
- Readiness and liveness probes against `/healthz`
- Resource requests of `100m` CPU and `128Mi` memory
- Resource limits of `500m` CPU and `256Mi` memory

The CI/CD deployment job substitutes `IMAGE_PLACEHOLDER` in `k8s/app/deployment.yaml`, applies the application manifests, applies the monitoring resources, and waits for the Deployment rollout.

The Service is `ClusterIP`, so it is intended for in-cluster access unless you configure an ingress, load balancer, port-forward, or another access method.

## Monitoring and Alerting

The application provides two endpoints used for observability:

- `/healthz` — returns an HTTP 200 response with a JSON status.
- `/metrics` — exposes Prometheus-format request counts by route and application uptime.

The monitoring directory contains a `PrometheusRule` alert named `WebsiteHighRequestBurst`. It evaluates the request rate for the `/` route over a three-minute window and raises a warning when the configured threshold is exceeded.

An `AlertmanagerConfig` defines an email receiver that references a Kubernetes Secret named `alertmanager-smtp-secret`, with key `smtp-password`. Create and manage this Secret securely in the `devops-project` namespace before expecting SMTP notifications to work. Do not place the SMTP password in source control.

These resources require a compatible Prometheus Operator installation and Alertmanager configuration that selects the resources and labels used by this project.

## Troubleshooting

- **GitLab job remains pending:** Verify the runner is online, eligible for the job, and configured with a compatible executor.
- **Docker build or login fails:** Check Docker-in-Docker support and the `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` variables.
- **SonarQube job fails:** Verify `SONAR_HOST_URL`, authentication, network access, and the project configuration. Note that this job currently allows failure.
- **Trivy job fails:** Inspect the reported findings; the current pipeline fails on CRITICAL vulnerabilities.
- **EKS authentication fails:** Verify AWS credentials, region, cluster name, and IAM/Kubernetes permissions.
- **Pods cannot pull the image:** Check the image tag and registry access from the cluster.
- **Rollout does not complete:** Inspect `kubectl describe deployment`, pod events, container logs, and readiness/liveness probe status.
- **Prometheus alert or email does not work:** Verify Prometheus Operator support, rule selection labels, Alertmanager configuration, and the `alertmanager-smtp-secret` Secret.

## Security Notes

- Never commit AWS keys, Docker Hub tokens, SonarQube tokens, or SMTP passwords.
- Use least-privilege AWS permissions and protected CI/CD variables.
- Review Terraform's public networking and EKS endpoint configuration before deploying to a production account.
- Review the current SonarQube `allow_failure` setting if code quality is intended to be a release gate.
- Keep base images, dependencies, and scanning tools updated.

## License

The `package.json` declares the project license as **MIT**. Ensure the repository contains the corresponding `LICENSE` file if you intend to distribute the project under that license.
