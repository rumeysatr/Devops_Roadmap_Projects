variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "public_key_path" {
  description = "SSH public key path"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "IP address allowed to connect with SSH"
  type        = string
}
