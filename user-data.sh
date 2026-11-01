#!/bin/bash
# EC2 User data: bootstraps an Apache web server on Amazon Linux 2023 at first boot.
# No SSH, no manual steps. Reads its own identity from the Instance Metadata Service (IMDSv2).
set -euxo pipefail

dnf install -y httpd
systemctl enable --now httpd

# IMDSv2: get a short-lived session token first, then query metadata with it
TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
md() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/$1; }
ID=$(md instance-id)
AZ=$(md placement/availability-zone)
TYPE=$(md instance-type)

cat > /var/www/html/index.html <<EOF
<!doctype html>
<title>Barry's EC2 server (automated)</title>
<h1>Built by a User data script, no manual steps</h1>
<p>Instance: $ID ($TYPE) in $AZ</p>
<p>Booted: $(date -u)</p>
EOF
