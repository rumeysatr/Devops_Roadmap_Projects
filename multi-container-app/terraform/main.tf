# En son resmi Ubuntu 24.04 (Noble) AMI'sını dinamik olarak bul
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical'ın AWS hesap ID'si (resmi Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "todo-app-key"
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "todo_app" {
  name        = "todo-app-sg"
  description = "Todo app: SSH restricted, HTTP open"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "todo_app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.todo_app.id]

  tags = {
    Name = "todo-app"
  }
}
