variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-1"
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro is Free Tier eligible in eu-west-1."
  type        = string
  default     = "t3.micro"
}

variable "name" {
  description = "Name used for the instance and as a prefix for related resources."
  type        = string
  default     = "my-web-server"
}

variable "http_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the web server on port 80."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
