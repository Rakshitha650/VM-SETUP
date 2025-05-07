provider "aws" {
  region = "ap-south-1" # Change the region as needed
}

variable "ami_id" {
  description = "Amazon Machine Image (AMI) ID for the EC2 instance"
  default     = "ami-023a307f3d27ea427" # Replace with your desired AMI (Ubuntu/Debian)
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH key name"
  default     = "mosip-qa" # Replace with your key pair name
}

resource "aws_instance" "performance_vm" {
  ami             = var.ami_id
  instance_type   = var.instance_type
  key_name        = var.key_name
  security_groups = [aws_security_group.perf_vm_sg.name]

  # Install required software packages
  user_data = file("install.sh")

  tags = {
    Name = "Performance-VM"
  }
}

resource "aws_security_group" "perf_vm_sg" {
  name        = "mosip-k8s-performance-vm25"
  description = "Allow necessary access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Change to restrict access
  }

  ingress {
    from_port   = 5900
    to_port     = 5900
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For VNC access
  }

  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"] # For WireGuard VPN
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "instance_public_ip" {
  description = "Public IP of the created instance"
  value       = aws_instance.performance_vm.public_ip
}