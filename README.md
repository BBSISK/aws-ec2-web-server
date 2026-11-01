# EC2 web server: manual build, then automated with User data

A first EC2 project on AWS (eu-west-1), done in two passes.

## 1. Manual build
- IAM role `ec2-ssm-role` (AWS managed policy `AmazonSSMManagedInstanceCore`) attached as an instance profile.
- `t3.micro`, Amazon Linux 2023, **no key pair**: shell access through **AWS Systems Manager Session Manager**, so no SSH keys to manage.
- Security group allows **HTTP (80) only**. The SSH rule the console adds by default was removed, because Session Manager doesn't need port 22.
- Installed Apache (`httpd`), started it and enabled it so it comes back after a reboot, then replaced the default page.

## 2. Automated build
Launched a second instance with the same role and security group and [`user-data.sh`](user-data.sh) as **User data**. On first boot it:
- installs and enables Apache,
- reads its own instance ID, type and Availability Zone from the **Instance Metadata Service (IMDSv2, token-based)**,
- writes a page showing them, which proves nobody configured it by hand.

Result: a working web server about a minute after launch, with zero manual steps.

## 3. Infrastructure as code (Terraform)
The whole stack is defined in Terraform, so one command creates it and one destroys it:

| File | What it defines |
|---|---|
| `main.tf` | IAM role + instance profile for SSM, HTTP-only security group, the instance (latest AL2023 AMI from the public SSM parameter, `user-data.sh`, IMDSv2 required, encrypted gp3 root volume, standard CPU credits) |
| `variables.tf` | region (`eu-west-1`), instance type (`t3.micro`), name, allowed HTTP CIDRs |
| `outputs.tf` | instance ID, public IP, URL, and the `aws ssm start-session` command |
| `.github/workflows/terraform.yml` | CI: `terraform fmt -check`, `init -backend=false`, `validate` on every push |

```bash
aws login --profile barry
export AWS_PROFILE=barry
terraform init
terraform plan
terraform apply      # prints the URL; give it ~1 minute to boot
terraform destroy    # removes everything it created
```

State is kept locally and gitignored, because the stack is short-lived. A longer-lived stack would use a remote S3 backend.

## What I learned
- **Networking** (VPC, subnet, security group) gets traffic to the box, **IAM** gets you into the box, and **Apache** serves content from the box.
- The public IPv4 address changes on stop/start. An Elastic IP or a load balancer is needed for a stable address.
- With no HTTPS, browsers that upgrade to `https://` time out. A real deployment would put TLS in front (ALB + ACM, or certbot).
- **IaaS vs PaaS:** on EC2 I own patching, TLS, process supervision and deploys. A platform like Render handles those for me. I'd use EC2 when I need control of the OS, networking or long-running processes.

## Clean-up
Both instances terminated afterwards, and their EBS volumes checked as deleted.

## Ideas for later
- HTTPS: Application Load Balancer + ACM certificate, or Caddy/certbot on the instance.
- Remote state in S3 with native locking.
