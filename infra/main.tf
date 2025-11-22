# Do not edit below unless you know what you're doing

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Cluster     = var.cluster_name
  }

  # Tags required for EKS subnets
  vpc_tags = merge(local.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# VPC Module
module "vpc" {
  source  = "Senora-dev/vpc/aws"
  version = "~>1.0.0"

  name     = "${var.cluster_name}-vpc"
  vpc_cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags                = local.vpc_tags
  public_subnet_tags  = local.public_subnet_tags
  private_subnet_tags = local.private_subnet_tags
}

# EKS Cluster Security Group
module "eks_cluster_sg" {
  source  = "Senora-dev/security-group/aws"
  version = "~>1.0.0"

  name   = "${var.cluster_name}-cluster-sg"
  vpc_id = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow HTTPS inbound from VPC"
      cidr_blocks = var.vpc_cidr
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allow all outbound traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

# EKS Node Security Group
module "eks_node_sg" {
  source  = "Senora-dev/security-group/aws"
  version = "~>1.0.0"

  name   = "${var.cluster_name}-node-sg"
  vpc_id = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      description = "Allow all TCP from VPC"
      cidr_blocks = var.vpc_cidr
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allow all outbound traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = merge(local.tags, {
    Name                                        = "${var.cluster_name}-node-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# EKS Cluster IAM Role
module "eks_cluster_role" {
  source  = "Senora-dev/iam-role/aws"
  version = "~>1.0.0"

  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
  use_name_prefix    = false

  managed_policy_arns = {
    AmazonEKSClusterPolicy         = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    AmazonEKSVPCResourceController = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  }

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-cluster-role"
  })
}

# EKS Node IAM Role
module "eks_node_role" {
  source  = "Senora-dev/iam-role/aws"
  version = "~>1.0.0"

  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
  use_name_prefix    = false

  managed_policy_arns = {
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-node-role"
  })
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = module.eks_cluster_role.iam_role_arn

  vpc_config {
    subnet_ids              = module.vpc.private_subnets
    endpoint_public_access  = true
    endpoint_private_access = true
    security_group_ids      = [module.eks_cluster_sg.security_group_id]
  }

  enabled_cluster_log_types = []

  tags = merge(local.tags, {
    Name = var.cluster_name
  })

  depends_on = [
    module.eks_cluster_role
  ]
}

# OIDC Provider for IRSA
resource "aws_iam_openid_connect_provider" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]

  tags = local.tags
}

# EKS Managed Node Group - System
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-ng-system"
  node_role_arn   = module.eks_node_role.iam_role_arn
  subnet_ids      = module.vpc.private_subnets
  version         = var.cluster_version

  capacity_type  = "ON_DEMAND"
  instance_types = var.system_node_instance_types

  scaling_config {
    desired_size = var.system_node_desired_size
    max_size     = var.system_node_max_size
    min_size     = var.system_node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "system"
  }

  tags = merge(local.tags, {
    Name                                            = "${var.cluster_name}-ng-system"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled"             = "true"
  })

  depends_on = [
    module.eks_node_role,
    aws_eks_cluster.main
  ]
}

# EKS Managed Node Group - App
resource "aws_eks_node_group" "app" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-ng-app"
  node_role_arn   = module.eks_node_role.iam_role_arn
  subnet_ids      = module.vpc.private_subnets
  version         = var.cluster_version

  capacity_type  = var.app_node_capacity_type
  instance_types = var.app_node_instance_types

  scaling_config {
    desired_size = var.app_node_desired_size
    max_size     = var.app_node_max_size
    min_size     = var.app_node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "application"
  }

  tags = merge(local.tags, {
    Name                                            = "${var.cluster_name}-ng-app"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled"             = "true"
  })

  depends_on = [
    module.eks_node_role,
    aws_eks_cluster.main
  ]
}

# EKS Add-ons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.15.1-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  addon_version               = "v1.28.2-eksbuild.2"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = "v1.10.1-eksbuild.6"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.tags

  depends_on = [
    aws_eks_node_group.system
  ]
}

# IAM Role for EBS CSI Driver (IRSA)
module "ebs_csi_irsa_role" {
  source  = "Senora-dev/iam-role/aws"
  version = "~>1.0.0"

  name               = "${var.cluster_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
  use_name_prefix    = false

  managed_policy_arns = {
    AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-ebs-csi-driver"
  })
}

# IAM Role for Cluster Autoscaler (IRSA)
module "cluster_autoscaler_irsa_role" {
  source  = "Senora-dev/iam-role/aws"
  version = "~>1.0.0"

  count = var.enable_cluster_autoscaler ? 1 : 0

  name               = "${var.cluster_name}-cluster-autoscaler"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume_role.json
  use_name_prefix    = false

  inline_policies = {
    ClusterAutoscalerPolicy = data.aws_iam_policy_document.cluster_autoscaler_policy.json
  }

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-cluster-autoscaler"
  })
}

# IAM Role for AWS Load Balancer Controller (IRSA)
module "aws_load_balancer_controller_irsa_role" {
  source  = "Senora-dev/iam-role/aws"
  version = "~>1.0.0"

  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name               = "${var.cluster_name}-aws-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json
  use_name_prefix    = false

  # Note: This requires the AWS Load Balancer Controller IAM policy to be created
  # Download from: https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  # For this template, we'll reference a managed policy ARN that should be pre-created
  inline_policies = {
    AWSLoadBalancerControllerPolicy = file("${path.module}/policies/aws-load-balancer-controller-policy.json")
  }

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-aws-lb-controller"
  })
}

# IAM Role for External DNS (IRSA)
module "external_dns_irsa_role" {
  source  = "Senora-dev/iam-role/aws"
  version = "~>1.0.0"

  count = var.enable_external_dns ? 1 : 0

  name               = "${var.cluster_name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role.json
  use_name_prefix    = false

  inline_policies = {
    ExternalDNSPolicy = data.aws_iam_policy_document.external_dns_policy.json
  }

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-external-dns"
  })
}

# Helm Release: EBS CSI Driver
resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.27.0"
  namespace  = "kube-system"

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.ebs_csi_irsa_role.iam_role_arn
  }

  depends_on = [aws_eks_cluster.main, aws_eks_node_group.system]
}

# Helm Release: Metrics Server
resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.11.0"
  namespace  = "kube-system"

  set {
    name  = "args[0]"
    value = "--kubelet-preferred-address-types=InternalIP"
  }

  depends_on = [aws_eks_cluster.main, aws_eks_node_group.system]
}

# Helm Release: Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.35.0"
  namespace  = "kube-system"

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.cluster_autoscaler_irsa_role[0].iam_role_arn
  }

  depends_on = [aws_eks_cluster.main, aws_eks_node_group.system]
}

# Helm Release: AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.6.2"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa_role[0].iam_role_arn
  }

  depends_on = [aws_eks_cluster.main, aws_eks_node_group.system]
}

# Helm Release: External DNS
resource "helm_release" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.14.0"
  namespace  = "kube-system"

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "aws.region"
    value = var.aws_region
  }

  set {
    name  = "domainFilters[0]"
    value = var.route53_zone_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.external_dns_irsa_role[0].iam_role_arn
  }

  depends_on = [aws_eks_cluster.main, aws_eks_node_group.system]
}

# Helm Release: Kubernetes Dashboard
resource "helm_release" "kubernetes_dashboard" {
  count = var.enable_kubernetes_dashboard ? 1 : 0

  name             = "kubernetes-dashboard"
  repository       = "https://kubernetes.github.io/dashboard/"
  chart            = "kubernetes-dashboard"
  version          = "7.0.0"
  namespace        = "kubernetes-dashboard"
  create_namespace = true

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "protocolHttp"
    value = "true"
  }

  depends_on = [aws_eks_cluster.main, aws_eks_node_group.system]
}
