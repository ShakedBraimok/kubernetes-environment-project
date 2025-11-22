output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "The endpoint of the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "The certificate authority data for the EKS cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The OIDC issuer URL of the EKS cluster"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "aws_region" {
  description = "The AWS region"
  value       = var.aws_region
}

output "cluster_security_group_id" {
  description = "The security group ID of the EKS cluster"
  value       = module.eks_cluster_sg.security_group_id
}

output "node_security_group_id" {
  description = "The security group ID of the EKS nodes"
  value       = module.eks_node_sg.security_group_id
}

output "cluster_iam_role_arn" {
  description = "The ARN of the EKS cluster IAM role"
  value       = module.eks_cluster_role.iam_role_arn
}

output "node_iam_role_arn" {
  description = "The ARN of the EKS node IAM role"
  value       = module.eks_node_role.iam_role_arn
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "The IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "The IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "ebs_csi_driver_role_arn" {
  description = "The ARN of the EBS CSI driver IAM role"
  value       = module.ebs_csi_irsa_role.iam_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "The ARN of the cluster autoscaler IAM role"
  value       = var.enable_cluster_autoscaler ? module.cluster_autoscaler_irsa_role[0].iam_role_arn : null
}

output "aws_load_balancer_controller_role_arn" {
  description = "The ARN of the AWS Load Balancer Controller IAM role"
  value       = var.enable_aws_load_balancer_controller ? module.aws_load_balancer_controller_irsa_role[0].iam_role_arn : null
}

output "external_dns_role_arn" {
  description = "The ARN of the external-dns IAM role"
  value       = var.enable_external_dns ? module.external_dns_irsa_role[0].iam_role_arn : null
}
