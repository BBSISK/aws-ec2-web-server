# EC2 web server: manual build → User data → Terraform

A first EC2 project on AWS (eu-west-1), done in three passes, each removing more manual steps.

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

### Verified run (1 Nov 2026)
- `terraform apply`: **7 added, 0 changed, 0 destroyed**. The instance was created in 17 s.
- Outputs gave the instance ID, public IP, URL and the `aws ssm start-session` command.
- The EC2 system log showed cloud-init running `user-data.sh`. IMDSv2 returned the instance ID, AZ (`eu-west-1a`) and type (`t3.micro`), and the page was written about 35 s after boot.
- `curl http://<public_ip>` returned the "Built by a User data script" page.
- `terraform destroy`: all 7 resources removed, leaving nothing running or billing.

### Troubleshooting note: `ERR_TIMED_OUT` in Chrome
The first browser check timed out even though the server was healthy. Chrome's *Always use secure connections* setting silently rewrote `http://` to `https://`. Port 443 isn't open in the security group, so the request was dropped (a timeout, not a refusal). I worked through it like this:
1. Checked the instance was running.
2. Read the boot log to confirm user data succeeded.
3. Checked the security group rules (HTTP in, all out).
4. Saw that the browser tab's URL had changed to `https://`.
5. Confirmed the server with `curl`.

## What I learned
- **Networking** (VPC, subnet, security group) gets traffic to the box, **IAM** gets you into the box, and **Apache** serves content from the box.
- The public IPv4 address changes on stop/start. An Elastic IP or a load balancer is needed for a stable address.
- With no HTTPS, browsers that upgrade to `https://` time out. A real deployment would put TLS in front (ALB + ACM, or certbot).
- **IaaS vs PaaS:** on EC2 I own patching, TLS, process supervision and deploys. A platform like Render handles those for me. I'd use EC2 when I need control of the OS, networking or long-running processes.
- A timeout and a refused connection point to different layers. A timeout means something is dropping packets (a firewall, or a port that isn't open). A refusal means the host is reachable but nothing is listening.

## Clean-up
- Manual and user-data builds: both instances terminated in the console, EBS volumes checked as deleted, and the security group and IAM role removed.
- Terraform build: `terraform destroy`.

## Ideas for later
- HTTPS: Application Load Balancer + ACM certificate, or Caddy/certbot on the instance.
- Remote state in S3 with native locking.
