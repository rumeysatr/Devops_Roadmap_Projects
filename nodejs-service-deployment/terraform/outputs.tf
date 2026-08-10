output "server_public_ip" {
  description = "Public IP of the Node.js server"
  value       = aws_instance.node_service.public_ip
}
