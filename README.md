# Kubernetes Environment-project

A complete, production-ready Kubernetes environment you can deploy in minutes. This template spins up an Amazon EKS cluster with all essentials pre-installed - autoscaling, ingress, storage, metrics, and example apps - so you can run containers in AWS without dealing with cluster plumbing.

# Quick Start Guide

Deploy a production-ready Kubernetes cluster on AWS EKS with managed node groups, auto-scaling, and essential add-ons. Follow this step-by-step guide with automated validation.

**Note:** EKS cluster provisioning takes approximately 15-20 minutes (AWS managed service deployment time).

## Prerequisites Checklist

Before you start, ensure you have:

- [ ] AWS CLI installed and configured (`aws --version`)
- [ ] Terraform >= 1.0 installed (`terraform version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] helm installed (`helm version`)
- [ ] AWS credentials configured (`aws sts get-caller-identity`)
- [ ] Appropriate AWS permissions (EKS, EC2, IAM, VPC, Route53)

## Architecture Overview

This template deploys:
- **EKS Cluster** with OIDC provider
- **VPC** with public/private subnets across 3 AZs
- **2 Managed Node Groups:**
  - System nodes (on-demand) for critical workloads
  - App nodes (spot/on-demand) for applications
- **EKS Add-ons:** VPC CNI, CoreDNS, kube-proxy
- **Helm Charts:** EBS CSI Driver, Cluster Autoscaler, Metrics Server, AWS Load Balancer Controller
- **IRSA** (IAM Roles for Service Accounts) for secure pod permissions

## Step 1: Configure Cluster Settings

Edit `envs/dev/terraform.tfvars`:

```hcl
# Cluster Configuration
cluster_name    = "my-cluster-dev"    # CHANGE THIS (must be globally unique)
cluster_version = "1.31"              # Check latest: aws eks describe-addon-versions
aws_region      = "us-east-1"         # CHANGE THIS
environment     = "dev"

# Network Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]  # CHANGE THIS

# Node Groups - System (Critical Workloads)
system_node_desired_size      = 2
system_node_min_size          = 2
system_node_max_size          = 4
system_node_instance_types    = ["t3.medium"]  # 2 vCPU, 4 GB RAM
system_node_disk_size         = 50

# Node Groups - Application (Your Workloads)
app_node_desired_size         = 2
app_node_min_size             = 2
app_node_max_size             = 10
app_node_instance_types       = ["t3.large"]   # 2 vCPU, 8 GB RAM
app_node_capacity_type        = "SPOT"         # SPOT or ON_DEMAND
app_node_disk_size            = 100

# Cluster Access - CRITICAL: Add your IAM users/roles
admin_user_arns = [
  "arn:aws:iam::123456789012:user/admin",           # CHANGE THIS
  "arn:aws:iam::123456789012:user/devops-user"      # CHANGE THIS
]
admin_role_arns = [
  "arn:aws:iam::123456789012:role/DevOpsRole"       # CHANGE THIS (if using roles)
]

# EKS Add-ons and Features
enable_cluster_autoscaler         = true
enable_metrics_server             = true
enable_aws_load_balancer_controller = true
enable_ebs_csi_driver             = true

# Optional: External DNS (requires Route53)
# enable_external_dns = true
# route53_zone_id     = "Z1234567890ABC"  # Your hosted zone ID

# Optional: Kubernetes Dashboard
# enable_kubernetes_dashboard = false

# Monitoring
cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
log_retention_days        = 7

# Tags
tags = {
  Project     = "my-project"
  Environment = "dev"
  ManagedBy   = "terraform"
}
```

**Key Configuration Decisions:**

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| `cluster_version` | 1.31 | 1.31 | 1.30 (stable) |
| `system_node_instance_types` | t3.medium | t3.large | t3.large |
| `app_node_capacity_type` | SPOT | SPOT | ON_DEMAND |
| `app_node_max_size` | 10 | 20 | 50 |
| `log_retention_days` | 7 | 30 | 90 |

**IMPORTANT:** Update `admin_user_arns` and `admin_role_arns` with your actual IAM identities, or you won't be able to access the cluster!

## Step 2: Configure Terraform Backend

Edit `infra/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"  # CHANGE THIS
    key            = "eks/dev/terraform.tfstate"
    region         = "us-east-1"                  # CHANGE THIS
    dynamodb_table = "terraform-state-lock"       # CHANGE THIS
    encrypt        = true
  }
}
```

**Create S3 bucket and DynamoDB table first:**
```bash
# Create S3 bucket
aws s3 mb s3://my-terraform-state-bucket --region us-east-1
aws s3api put-bucket-versioning \
  --bucket my-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Step 3: Validate Configuration

```bash
# Check prerequisites
make bootstrap

# Run all validation checks
make all-checks ENV=dev

# Or run individually:
make fmt ENV=dev       # Format Terraform code
make validate ENV=dev  # Validate configuration
make tflint ENV=dev    # Lint Terraform
make checkov ENV=dev   # Security scan
```

## Step 4: Deploy EKS Cluster

```bash
# Initialize Terraform
make init ENV=dev

# Preview changes
make plan ENV=dev

# Deploy cluster (this takes 15-20 minutes)
make apply ENV=dev
```

**What gets created:**
- VPC with 3 public + 3 private subnets
- Internet Gateway and NAT Gateways
- EKS cluster control plane
- OIDC provider for IRSA
- Security groups
- 2 managed node groups (system and app)
- EBS CSI Driver with IAM role
- Cluster Autoscaler with IAM role
- Metrics Server
- AWS Load Balancer Controller with IAM role
- EKS add-ons (VPC CNI, CoreDNS, kube-proxy)

**Coffee break recommended.** ☕

## Step 5: Configure kubectl

```bash
# Configure kubectl to connect to your cluster
make configure-kubectl ENV=dev

# Verify connection
kubectl cluster-info

# Check nodes
kubectl get nodes

# Expected output:
# NAME                         STATUS   ROLES    AGE   VERSION
# ip-10-0-1-123.ec2.internal   Ready    <none>   5m    v1.31.0-eks-xxx
# ip-10-0-2-456.ec2.internal   Ready    <none>   5m    v1.31.0-eks-xxx
# ...
```

## Step 6: Verify Deployment

```bash
# Run comprehensive verification
make verify

# This checks:
# - Cluster is accessible
# - Nodes are ready
# - System pods are running
# - Add-ons are healthy
# - IRSA is configured correctly
```

**Manual verification:**
```bash
# Check all system pods
kubectl get pods -A

# Verify critical components
kubectl get pods -n kube-system | grep -E "coredns|aws-node|kube-proxy"
kubectl get pods -n kube-system | grep -E "ebs-csi|cluster-autoscaler|metrics-server|aws-load-balancer"

# Check node labels (for workload placement)
kubectl get nodes --show-labels | grep -E "system|app"

# Verify IRSA (IAM roles for service accounts)
kubectl get sa -n kube-system ebs-csi-controller-sa -o yaml | grep eks.amazonaws.com/role-arn
```

## Step 7: Deploy Sample Application (Optional, 2 minutes)

```bash
# Deploy hello-world app to test the cluster
cd examples/hello-app
kubectl apply -f deployment.yaml

# Check deployment
kubectl get pods
kubectl get svc

# If using AWS Load Balancer Controller:
kubectl get ingress
# Wait for ALB to be provisioned, then access the EXTERNAL-IP
```

## Common Deployment Issues

### Nodes Not Joining Cluster?

1. **Check node group status:**
   ```bash
   aws eks describe-nodegroup \
     --cluster-name my-cluster-dev \
     --nodegroup-name system \
     --region us-east-1
   ```

2. **Check IAM roles:**
   ```bash
   aws iam get-role --role-name eks-node-group-role
   ```

3. **Verify security groups** allow node-to-control-plane communication

### Can't Access Cluster with kubectl?

1. **Verify IAM permissions:**
   ```bash
   aws sts get-caller-identity
   # Make sure this matches one of the admin_user_arns
   ```

2. **Reconfigure kubectl:**
   ```bash
   make configure-kubectl ENV=dev
   ```

3. **Check aws-auth ConfigMap:**
   ```bash
   kubectl get configmap aws-auth -n kube-system -o yaml
   ```

### Pods Pending/Not Scheduling?

1. **Check node resources:**
   ```bash
   kubectl describe nodes
   kubectl top nodes  # Requires metrics-server
   ```

2. **Check pod events:**
   ```bash
   kubectl describe pod <POD_NAME>
   ```

3. **Verify cluster autoscaler:**
   ```bash
   kubectl logs -n kube-system deployment/cluster-autoscaler
   ```

## Next Steps

### Deploy Your Applications

```bash
# Create namespace
kubectl create namespace my-app

# Deploy application
kubectl apply -f your-deployment.yaml -n my-app

# Expose with ALB
kubectl apply -f your-ingress.yaml -n my-app
```

**Example Ingress with ALB:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-service
                port:
                  number: 80
```

### Set Up Monitoring

1. **Install Prometheus & Grafana:**
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm install prometheus prometheus-community/kube-prometheus-stack \
     --namespace monitoring \
     --create-namespace
   ```

2. **Access Grafana:**
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
   # Visit http://localhost:3000 (admin/prom-operator)
   ```

### Set Up Logging

1. **Install Fluent Bit for CloudWatch Logs:**
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml
   ```

2. **View logs in CloudWatch:**
   - Log Group: `/aws/eks/my-cluster-dev/cluster`
   - Container Insights: CloudWatch → Container Insights

### Configure Auto-Scaling

**Horizontal Pod Autoscaler (HPA):**
```bash
kubectl autoscale deployment my-app \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n my-app
```

**Cluster Autoscaler** is already configured and will add/remove nodes automatically based on pod resource requests.

### Set Up CI/CD

Example GitHub Actions workflow:

```yaml
name: Deploy to EKS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --name my-cluster-dev --region us-east-1

      - name: Deploy to EKS
        run: |
          kubectl apply -f k8s/ -n my-app
          kubectl rollout status deployment/my-app -n my-app
```

### Deploy to Production

```bash
# Create production configuration
mkdir -p envs/prod
cp envs/dev/terraform.tfvars envs/prod/terraform.tfvars

# Edit production settings:
# - Change cluster_name to "my-cluster-prod"
# - Use ON_DEMAND capacity type
# - Increase node counts and sizes
# - Increase log retention
# - Add production IAM users/roles
# - Enable additional security features

# Deploy to production
make init ENV=prod
make plan ENV=prod
make apply ENV=prod
make configure-kubectl ENV=prod
```

## Cost Optimization Tips

1. **Use Spot Instances for non-critical workloads:**
   ```hcl
   app_node_capacity_type = "SPOT"
   ```
   Can save up to 90% on compute costs.

2. **Right-size node instances:**
   - Start with smaller instances and scale up based on actual usage
   - Use `kubectl top nodes` to monitor resource usage

3. **Configure Cluster Autoscaler:**
   - Already included in template
   - Automatically scales down underutilized nodes

4. **Use Fargate for sporadic workloads:**
   - No need to run nodes 24/7
   - Pay only when pods are running

5. **Optimize EBS volumes:**
   - Use gp3 instead of gp2 (cheaper and faster)
   - Right-size disk space

## Troubleshooting Commands

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes -o wide

# Check control plane logs
aws eks list-clusters
aws logs tail /aws/eks/my-cluster-dev/cluster --follow

# Node group status
aws eks list-nodegroups --cluster-name my-cluster-dev
aws eks describe-nodegroup --cluster-name my-cluster-dev --nodegroup-name app

# Pod issues
kubectl get pods -A
kubectl describe pod <POD_NAME> -n <NAMESPACE>
kubectl logs <POD_NAME> -n <NAMESPACE>

# Service account and IRSA
kubectl get sa -A
kubectl describe sa <SERVICE_ACCOUNT> -n <NAMESPACE>

# Cluster autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler --follow

# Load balancer controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller --follow
```

## Clean Up

To remove all resources:

```bash
# IMPORTANT: Delete all LoadBalancers and PersistentVolumes first!
# These create AWS resources outside Terraform's control

# Delete all services of type LoadBalancer
kubectl get svc -A -o json | \
  jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' | \
  while read ns name; do kubectl delete svc $name -n $ns; done

# Delete all PersistentVolumeClaims (EBS volumes)
kubectl get pvc -A -o json | \
  jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | \
  while read ns name; do kubectl delete pvc $name -n $ns; done

# Wait for resources to be cleaned up
sleep 180

# Now destroy Terraform resources
make destroy ENV=dev
```

**What gets deleted:**
- EKS cluster and node groups
- VPC and all networking resources
- IAM roles and policies
- EBS volumes (if PVCs were deleted)
- Load balancers (if Services were deleted)
- CloudWatch log groups

## Need Help?

- Check the main [README.md](./README.md) for detailed documentation
- Review [examples/hello-app/README.md](./examples/hello-app/README.md)
- Run `make help` to see all available commands
- Check EKS logs: `aws logs tail /aws/eks/my-cluster-dev/cluster --follow`
- Review [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)


## Environment Variables

This project uses environment-specific variable files in the `envs/` directory.

### dev
Variables are stored in `envs/dev/terraform.tfvars`

### dev2
Variables are stored in `envs/dev2/terraform.tfvars`



## GitHub Actions CI/CD

This project includes automated Terraform validation via GitHub Actions.

### Required GitHub Secrets

Configure these in Settings > Secrets > Actions:

- `AWS_ACCESS_KEY_ID`: Your AWS Access Key
- `AWS_SECRET_ACCESS_KEY`: Your AWS Secret Key
- `TF_STATE_BUCKET`: `senora-terraform-state-kubernetes-environment-project-69214fc7307cdc8b159f63e9`
- `TF_STATE_KEY`: `kubernetes-environment-project/terraform.tfstate`


---
*Generated by [Senora](https://senora.dev)*
