data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 3)

  common_tags = merge(var.tags, {
    Project   = var.cluster_name
    ManagedBy = "Terraform"
  })

  node_groups = {
    frontend = {
      instance_types = [var.frontend_instance_type]
    }
    backend = {
      instance_types = [var.backend_instance_type]
    }
    database = {
      instance_types = [var.database_instance_type]
    }
    monitoring = {
      instance_types = [var.monitoring_instance_type]
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  azs  = local.availability_zones

  private_subnets = [for index in range(3) : cidrsubnet(var.vpc_cidr, 8, index)]
  public_subnets  = [for index in range(3) : cidrsubnet(var.vpc_cidr, 8, index + 100)]

  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = true
  single_nat_gateway   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = local.common_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  bootstrap_self_managed_addons            = false
  enable_irsa                              = false
  enable_cluster_creator_admin_permissions = true

  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_enabled_log_types            = ["api", "audit", "authenticator"]

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
  }

  eks_managed_node_groups = {
    for name, config in local.node_groups : name => {
      name                     = "${var.cluster_name}-${name}"
      iam_role_name            = name == "monitoring" ? "${var.cluster_name}-monitor-node" : null
      iam_role_use_name_prefix = name != "monitoring"
      ami_type                 = "AL2023_x86_64_STANDARD"
      instance_types           = config.instance_types
      capacity_type            = "ON_DEMAND"
      min_size                 = 1
      desired_size             = 1
      max_size                 = 3

      labels = {
        workload = name
      }

      tags = merge(local.common_tags, {
        Workload = name
      })
    }
  }

  tags = local.common_tags
}

