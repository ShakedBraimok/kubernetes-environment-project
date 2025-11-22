variable "aws_region" {
  description = "The AWS region to deploy the resources."
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "The name of the application."
  type        = string
  default     = "app"
}

variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
  default     = "app-cluster"
}

variable "cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler add-on."
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Enable metrics server add-on."
  type        = bool
  default     = true
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller add-on."
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Enable external-dns add-on."
  type        = bool
  default     = false
}

variable "enable_kubernetes_dashboard" {
  description = "Enable Kubernetes dashboard add-on."
  type        = bool
  default     = false
}

variable "enable_example_app" {
  description = "Deploy the example hello-app application."
  type        = bool
  default     = false
}

variable "system_node_instance_types" {
  description = "Instance types for system node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "system_node_desired_size" {
  description = "Desired number of nodes in system node group."
  type        = number
  default     = 2
}

variable "system_node_min_size" {
  description = "Minimum number of nodes in system node group."
  type        = number
  default     = 1
}

variable "system_node_max_size" {
  description = "Maximum number of nodes in system node group."
  type        = number
  default     = 4
}

variable "app_node_instance_types" {
  description = "Instance types for application node group."
  type        = list(string)
  default     = ["t3.medium", "t3.large"]
}

variable "app_node_desired_size" {
  description = "Desired number of nodes in application node group."
  type        = number
  default     = 2
}

variable "app_node_min_size" {
  description = "Minimum number of nodes in application node group."
  type        = number
  default     = 1
}

variable "app_node_max_size" {
  description = "Maximum number of nodes in application node group."
  type        = number
  default     = 10
}

variable "app_node_capacity_type" {
  description = "Capacity type for application node group (ON_DEMAND or SPOT)."
  type        = string
  default     = "SPOT"
}

variable "admin_role_arns" {
  description = "List of IAM role ARNs to grant cluster admin access."
  type        = list(string)
  default     = []
}

variable "admin_user_arns" {
  description = "List of IAM user ARNs to grant cluster admin access."
  type        = list(string)
  default     = []
}

variable "developer_role_arns" {
  description = "List of IAM role ARNs to grant cluster developer access."
  type        = list(string)
  default     = []
}

variable "route53_zone_id" {
  description = "Route53 zone ID for external-dns (required if external-dns is enabled)."
  type        = string
  default     = ""
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for EKS cluster."
  type        = bool
  default     = false
}
