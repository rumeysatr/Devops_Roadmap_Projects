variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-central-1"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "public_key_path" {
  type        = string
  description = "Path to local SSH public key"
}

variable "ssh_allowed_cidr" {
  type        = string
  description = "CIDR allowed to connect through SSH"
}
