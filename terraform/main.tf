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

variable "VNC_USERNAME" {
}

variable "VNC_PASSWORD" {
}
resource "aws_instance" "performance_vm" {
  ami             = var.ami_id
  instance_type   = var.instance_type
  key_name        = var.key_name
  security_groups = [aws_security_group.perf_vm_sg.name]

  # Install required software packages
  user_data = templatefile("./install.sh.tpl",{
   VNC_USERNAME= var.VNC_USERNAME
   VNC_PASSWORD= var.VNC_PASSWORD
      })

  tags = {
    Name = "Performance-VM"
  }
}

resource "aws_security_group" "perf_vm_sg" {
  name        = "mosip-k8s-performance-vm2000"
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

output "instance_private_ip" {
  description = "Private IP of the created instance"
  value       = aws_instance.performance_vm.private_ip
}