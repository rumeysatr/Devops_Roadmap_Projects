variable "aws_region" {
	description = "AWS bölgesi"
	type = string
	default = "eu-central-1"
}

variable "instance_type" {
	description = "EC2 örnek tipi"
	type = string
	default = "t3.micro"
}

variable "public_key_path" {
	description = "AWS'e yüklenecek SSH public key'in yolu"
	type = string
}

variable "ssh_allowed_cidr" {
	description = "SSH erişimine izin verilen IP aralığı (CIDR). Güvenlik için kendi IP'ni kullan."
	type = string
}
