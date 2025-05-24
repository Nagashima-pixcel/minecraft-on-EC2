terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.98.0"
    }
  }

  required_version = ">= 1.12.1"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_instance" "minecraft" {
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name = "moyomoto's Minecraft Server"
  }
}
