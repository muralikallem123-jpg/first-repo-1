variable "aws_region" {
  description = "AWS region for the EKS cluster and ACM certificate."
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  description = "Name used for the EKS cluster and related resources."
  type        = string
  default     = "eks-practice"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version currently supported in the selected region."
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the new VPC. The current subnet layout expects a /16."
  type        = string
  default     = "10.20.0.0/16"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Public IPv4 CIDRs allowed to reach the Kubernetes API; normally restrict these to trusted /32 addresses."
  type        = list(string)

  validation {
    condition = (
      length(var.cluster_endpoint_public_access_cidrs) > 0 &&
      (!contains(var.cluster_endpoint_public_access_cidrs, "0.0.0.0/0") || var.allow_public_api_from_anywhere) &&
      (!var.allow_public_api_from_anywhere || contains(var.cluster_endpoint_public_access_cidrs, "0.0.0.0/0"))
    )
    error_message = "Provide at least one CIDR. Use 0.0.0.0/0 only when allow_public_api_from_anywhere is true."
  }
}

variable "allow_public_api_from_anywhere" {
  description = "Temporary practice-only override to allow any IPv4 address to reach the public EKS API endpoint."
  type        = bool
  default     = false
}

variable "frontend_instance_type" {
  description = "Instance type for the frontend node group; choose an x86 type allowed by the AWS account."
  type        = string
  default     = "t3.small"
}

variable "backend_instance_type" {
  description = "Instance type for the backend node group; choose an x86 type allowed by the AWS account."
  type        = string
  default     = "t3.small"
}

variable "database_instance_type" {
  description = "Instance type for the database node group; t3.small is for a small practice workload only."
  type        = string
  default     = "t3.small"
}

variable "monitoring_instance_type" {
  description = "Instance type for monitoring add-ons; use an x86 type allowed by the AWS account."
  type        = string
  default     = "c7i-flex.large"
}

variable "tags" {
  description = "Additional tags to apply to AWS resources."
  type        = map(string)
  default     = {}
}