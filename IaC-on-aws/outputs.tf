output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.server.id
}

output "public_ip" {
  description = "EC2 public IP"
  value       = aws_instance.server.public_ip
}

output "ssh_command" {
  description = "SSH connection command"
  value       = "ssh -i ${trimsuffix(var.public_key_path, ".pub")} ubuntu@${aws_instance.server.public_ip}"
}
