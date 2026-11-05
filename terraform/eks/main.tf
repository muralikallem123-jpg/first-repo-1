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
  enable_irsa                              = true
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
      name           = "${var.cluster_name}-${name}"
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = config.instance_types
      capacity_type  = "ON_DEMAND"
      min_size       = 1
      desired_size   = 1
      max_size       = 3

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

resource "aws_autoscaling_group_tag" "cluster_autoscaler_enabled" {
  for_each = local.node_groups

  autoscaling_group_name = module.eks.eks_managed_node_groups[each.key].node_group_autoscaling_group_names[0]

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = false
  }
}

resource "aws_autoscaling_group_tag" "cluster_autoscaler_cluster" {
  for_each = local.node_groups

  autoscaling_group_name = module.eks.eks_managed_node_groups[each.key].node_group_autoscaling_group_names[0]

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true
  oidc_providers = {
    eks = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.common_tags
}

data "aws_eks_addon_version" "ebs_csi" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = data.aws_eks_addon_version.ebs_csi.version
  service_account_role_arn = module.ebs_csi_irsa.iam_role_arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.24.3"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  create_delay_dependencies = [
    for node_group in values(module.eks.eks_managed_node_groups) : node_group.node_group_arn
  ]

  enable_aws_load_balancer_controller = true
  enable_cluster_autoscaler           = true
  enable_external_dns                 = var.external_dns_enabled
  external_dns_route53_zone_arns = var.external_dns_enabled ? [
    "arn:aws:route53:::hostedzone/${var.route53_hosted_zone_id}"
  ] : []

  aws_load_balancer_controller = {
    chart_version = "1.14.0"
    values = [yamlencode({
      region = var.aws_region
      vpcId  = module.vpc.vpc_id
      nodeSelector = {
        workload = "monitoring"
      }
    })]
  }

  cluster_autoscaler = {
    chart_version      = "9.60.0"
    image_tag_override = "v1.35.0"
    values = [yamlencode({
      nodeSelector = {
        workload = "monitoring"
      }
    })]
  }

  external_dns = {
    chart_version = "1.23.0"
    values = [yamlencode({
      provider = {
        name = "aws"
      }
      domainFilters = var.external_dns_enabled ? [var.domain_name] : []
      sources       = ["ingress"]
      policy        = "upsert-only"
      registry      = "txt"
      txtOwnerId    = var.cluster_name
      nodeSelector = {
        workload = "monitoring"
      }
    })]
  }

  observability_tag = null
  tags              = local.common_tags

  depends_on = [aws_eks_addon.ebs_csi]
}