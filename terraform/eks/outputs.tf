output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_region" {
  description = "AWS region used for the cluster."
  value       = var.aws_region
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "VPC hosting EKS."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets used by worker nodes."
  value       = module.vpc.private_subnets
}

output "external_dns_hosted_zone_id" {
  description = "Existing public Route 53 hosted zone ID used by ExternalDNS."
  value       = var.route53_hosted_zone_id
}

output "node_group_labels" {
  description = "Workload label assigned to each EKS managed node group."
  value = {
    for name, config in local.node_groups : name => "workload=${name}"
  }
}