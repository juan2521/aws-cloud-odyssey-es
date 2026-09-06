variable "aws_region" { type = string; default = "us-east-1" }
variable "cluster_name" { type = string; default = "odyssey-eks-prod" }
variable "vpc_cidr" { type = string; default = "10.30.0.0/16" }
variable "kubernetes_version" {
  type        = string
  description = "Set to an EKS-supported Kubernetes version validated for your deployment date."
}
variable "platform_admin_role_arn" {
  type        = string
  description = "IAM role used for controlled platform administration, ideally federated through IAM Identity Center."
}
