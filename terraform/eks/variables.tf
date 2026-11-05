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
  description = "Trusted public IPv4 CIDRs allowed to reach the Kubernetes API. Use your current public IP with /32."
  type        = list(string)

  validation {
    condition     = length(var.cluster_endpoint_public_access_cidrs) > 0 && !contains(var.cluster_endpoint_public_access_cidrs, "0.0.0.0/0")
    error_message = "Provide at least one trusted CIDR; do not expose the EKS API to 0.0.0.0/0."
  }
}

variable "domain_name" {
  description = "Existing public Route 53 hosted zone domain used by ExternalDNS when enabled, for example example.com."
  type        = string
  default     = ""

  validation {
    condition     = !var.external_dns_enabled || length(trimspace(var.domain_name)) > 0
    error_message = "Set domain_name when external_dns_enabled is true."
  }
}

variable "route53_hosted_zone_id" {
  description = "ID of the existing public Route 53 hosted zone for ExternalDNS when enabled, without the /hostedzone/ prefix."
  type        = string
  default     = ""

  validation {
    condition     = !var.external_dns_enabled || length(trimspace(var.route53_hosted_zone_id)) > 0
    error_message = "Set route53_hosted_zone_id when external_dns_enabled is true."
  }
}

variable "external_dns_enabled" {
  description = "Enable ExternalDNS after a public Route 53 hosted zone has been created manually."
  type        = bool
  default     = false
}

variable "frontend_instance_type" {
  description = "Instance type for the frontend node group."
  type        = string
  default     = "t3.medium"
}

variable "backend_instance_type" {
  description = "Instance type for the backend node group."
  type        = string
  default     = "t3.medium"
}

variable "database_instance_type" {
  description = "Instance type for the database node group."
  type        = string
  default     = "t3.large"
}

variable "monitoring_instance_type" {
  description = "Instance type for the monitoring node group."
  type        = string
  default     = "t3.medium"
}

variable "tags" {
  description = "Additional tags to apply to AWS resources."
  type        = map(string)
  default     = {}
}