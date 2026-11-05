# EKS Practice Cluster

This reduced Terraform configuration creates a VPC, an EKS cluster with four managed node groups, and the core EKS networking add-ons. OIDC-dependent add-ons are deferred because this demo account's organization policy blocks OIDC provider creation.

## Before You Apply

- For this practice pipeline, use a dedicated non-root IAM user with permission to create the listed VPC, EKS, IAM, and Auto Scaling resources. Never use root access keys. IAM user keys are long-lived; use a role/federation for real workloads and delete or rotate the practice key when finished.
- The example is set to `ap-southeast-2` and Kubernetes `1.35`. Check that `1.35` is in standard support in your region before applying. The add-on chart versions in `main.tf` are matched to Kubernetes `1.35`; if you change Kubernetes versions, update the Cluster Autoscaler chart and image tag to matching releases as well.
- Install Terraform 1.10+, AWS CLI, and kubectl. The AWS CLI identity must be able to create the infrastructure and later authenticate to the EKS cluster.
- Create a private, versioned S3 bucket for Terraform state before `terraform init`. S3 native state locking is enabled by the init command below.
- The first cluster run does not require Route 53 or ACM. Create the public hosted zone and regional ACM certificate manually later, before configuring custom DNS/HTTPS ingress.
- This first phase does not install EBS CSI, Cluster Autoscaler, AWS Load Balancer Controller, or ExternalDNS. Add them later if the account's organization policy permits the required AWS identity setup.
- Choose an EKS Kubernetes version supported in your AWS region and by the pinned Cluster Autoscaler add-on.
- The public Kubernetes API is restricted to `cluster_endpoint_public_access_cidrs` by default. Replace the documentation-only address in the example with your current public IP `/32`.
- For a short practice-only test, Jenkins has a `TEMPORARY_OPEN_API` parameter that sets the CIDR to `0.0.0.0/0`. This exposes the Kubernetes API to the internet. Turn it off immediately after testing and rerun Terraform with trusted CIDRs.

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

Edit `terraform.tfvars` with a supported Kubernetes version and your trusted public API CIDR. Keep `allow_public_api_from_anywhere = false` for normal use. `terraform.tfvars` is ignored by Git; do not commit credentials or secrets.

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
5. Normally run the job with Jenkins/CloudShell egress addresses as comma-separated `/32` entries in `ADMIN_CIDR`. Only for a brief practice test, select `TEMPORARY_OPEN_API` instead; it opens the Kubernetes API to all IPv4 addresses.
6. The job checks the AWS identity and verifies that Kubernetes `1.35` is in standard support in the selected region. It runs Terraform init, formatting/validation, imports any pre-existing `coredns`, `kube-proxy`, or `vpc-cni` add-ons not already tracked in the same Terraform state, then prints the plan and automatically applies it if the earlier stages succeed. Every run can change billable AWS resources; inspect the plan output and parameter values before starting the job.

The Jenkins identity needs S3 state access (`s3:ListBucket`, `s3:GetObject`, `s3:PutObject`, and state-lock file operations) plus permissions for the resources Terraform manages, including IAM role creation and `iam:PassRole`. It also needs to read EKS version metadata in `ap-southeast-2`. Scope these permissions to the demo account/resources where practical. The pipeline does not create its own state bucket.

## Verify the Cluster

```powershell
aws eks update-kubeconfig --region <YOUR_AWS_REGION> --name eks-practice
kubectl get nodes --show-labels
```

Each node group has a `workload` label: `frontend`, `backend`, `database`, or `monitoring`.

This reduced configuration enables the EKS-managed VPC CNI, CoreDNS, and kube-proxy add-ons. EBS CSI, Cluster Autoscaler, AWS Load Balancer Controller, and ExternalDNS are deferred because the current account policy blocks OIDC creation.

This phase creates no application Ingress or load balancer. After deploying the app, use `kubectl port-forward` to browse it locally. An ALB-based Ingress requires the AWS Load Balancer Controller, which must wait until the account permits the required identity integration. Without EBS CSI, database data on a pod's local filesystem is temporary.

## Destroy Practice Resources

Before destroying, remove Kubernetes Services/Ingresses that created AWS load balancers and delete any persistent data you need to keep. Then run `terraform destroy` from this folder. Review the destroy plan; Route 53 delegation and externally created S3 state bucket are not removed by this configuration.