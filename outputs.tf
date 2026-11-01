output "instance_id" {
  value = aws_instance.web.id
}

output "public_ip" {
  value = aws_instance.web.public_ip
}

output "url" {
  description = "Open with http:// (there is no HTTPS listener)."
  value       = "http://${aws_instance.web.public_ip}"
}

output "ssm_session_command" {
  description = "Shell into the instance without SSH (needs the Session Manager plugin for the AWS CLI)."
  value       = "aws ssm start-session --target ${aws_instance.web.id} --region ${var.region}"
}
