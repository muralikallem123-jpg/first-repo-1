# EKS Practice Cluster

This Terraform configuration creates a VPC, an EKS cluster with four managed node groups, required EKS add-ons, cluster autoscaling, and AWS controllers. You create the Route 53 hosted zone and ACM certificate separately; Terraform accepts the existing public hosted-zone ID for ExternalDNS.

## Before You Apply

- For this practice pipeline, create a dedicated non-root IAM user with permissions to create the listed VPC, EKS, IAM roles/OIDC providers, and Auto Scaling resources. Terraform reads the existing Route 53 hosted-zone ID and does not create DNS zones, DNS records, or ACM certificates. Never use root access keys. IAM user keys are long-lived; use a role/federation for real workloads and delete or rotate the practice key when finished.
- The example is set to `ap-southeast-2` and Kubernetes `1.35`. Check that `1.35` is in standard support in your region before applying. The add-on chart versions in `main.tf` are matched to Kubernetes `1.35`; if you change Kubernetes versions, update the Cluster Autoscaler chart and image tag to matching releases as well.
- Install Terraform 1.10+, AWS CLI, and kubectl. The AWS CLI identity must be able to create the infrastructure and later authenticate to the EKS cluster.
- Create a private, versioned S3 bucket for Terraform state before `terraform init`. S3 native state locking is enabled by the init command below.
- The first cluster run does not require Route 53 or ACM. Create the public hosted zone and regional ACM certificate manually later, before configuring custom DNS/HTTPS ingress.
- ExternalDNS is disabled by default. After creating the hosted zone manually, set `external_dns_enabled = true`, copy its ID into `route53_hosted_zone_id`, and set `domain_name` to the zone's domain. ExternalDNS is scoped to that zone and only watches Ingress resources.
- Choose an EKS Kubernetes version supported in your AWS region and by the pinned Cluster Autoscaler add-on.
- The public Kubernetes API is restricted to `cluster_endpoint_public_access_cidrs`. Replace the documentation-only address in the example with your current public IP `/32`.

Check standard-support Kubernetes versions in the target region:

```powershell
aws eks describe-cluster-versions --region ap-southeast-2 --version-status STANDARD_SUPPORT --query "clusterVersions[].clusterVersion" --output table
```

## Configure

From PowerShell:

```powershell
cd terraform/eks
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with a supported Kubernetes version and your trusted public API CIDR. Leave ExternalDNS disabled and its DNS values empty for the first cluster deployment. `terraform.tfvars` is ignored by Git; do not commit credentials or secrets.

## Plan and Create

```powershell
terraform init -backend-config="bucket=<YOUR_TERRAFORM_STATE_BUCKET>" -backend-config="key=eks-practice/terraform.tfstate" -backend-config="region=<YOUR_AWS_REGION>" -backend-config="encrypt=true" -backend-config="use_lockfile=true"
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Review the plan carefully before applying. Four continuously running node groups, the EKS control plane, NAT Gateway, and storage incur AWS charges.

## Run from Jenkins

1. Create a private, versioned S3 bucket in `ap-southeast-2` for Terraform state. The bucket must exist before the first pipeline run.
2. On the Jenkins controller/agent, install Terraform `1.10+` and AWS CLI v2. Install the Jenkins **AWS Credentials** plugin.
3. In **Manage Jenkins → Credentials**, add the IAM user's access key as credential type **AWS Credentials**, with ID `aws-demo-terraform`. Do not put keys in this repository, build parameters, or the Jenkinsfile.
4. Create a Jenkins **Pipeline** job configured as **Pipeline script from SCM**. Select Git, your repository and branch, and set **Script Path** to `jenkins/Jenkinsfile.eks`.
5. Run the job with region `ap-southeast-2`, cluster name `eks-practice`, Kubernetes version `1.35`, ExternalDNS disabled, your public IP as `ADMIN_CIDR` (for example `198.51.100.25/32`), and the S3 state bucket name. Add the domain and hosted-zone ID only when enabling ExternalDNS later.
6. The job checks the AWS identity and verifies that Kubernetes `1.35` is in standard support in the selected region. It runs Terraform init, formatting/validation, and plan, prints the full plan, then pauses for approval before apply. Reject/abort the input to avoid creating resources.

The Jenkins identity needs S3 state access (`s3:ListBucket`, `s3:GetObject`, `s3:PutObject`, and state-lock file operations) plus permissions for the resources Terraform manages, including IAM role creation and `iam:PassRole`. It also needs to read EKS version metadata in `ap-southeast-2`. Scope these permissions to the demo account/resources where practical. The pipeline does not create its own state bucket.

## Verify the Cluster

```powershell
aws eks update-kubeconfig --region <YOUR_AWS_REGION> --name eks-practice
kubectl get nodes --show-labels
```

Each node group has a `workload` label: `frontend`, `backend`, `database`, or `monitoring`.

The EKS managed add-ons include VPC CNI, CoreDNS, kube-proxy, and the EBS CSI driver. EBS CSI uses a dedicated IRSA role. EKS Blueprints Add-ons installs Cluster Autoscaler and AWS Load Balancer Controller; ExternalDNS is optional and disabled for the first cluster run. The node group Auto Scaling Groups are tagged for autoscaler discovery.

Terraform installs the AWS Load Balancer Controller, but it does not create an application Ingress or load balancer. After deploying Argo CD and the application charts, add Kubernetes Ingress resources to route traffic. The controller creates an ALB, and you can test its AWS-generated DNS hostname over HTTP first. Later, set the manually created ACM certificate ARN on the Ingress for HTTPS; optionally enable ExternalDNS to publish the custom hostname in your hosted zone.

## Destroy Practice Resources

Before destroying, remove Kubernetes Services/Ingresses that created AWS load balancers and delete any persistent data you need to keep. Then run `terraform destroy` from this folder. Review the destroy plan; Route 53 delegation and externally created S3 state bucket are not removed by this configuration.