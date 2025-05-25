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

data "aws_vpc" "default" {
  default = true
}

// セキュリティグループ定義
resource "aws_security_group" "minecraft_sg" {
  name        = "minecraft-sg"
  description = "Allow Minecraft and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.public_ip
  }

  ingress {
    description = "Minecraft"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "minecraft-sg"
  }
}

// EC2インスタンス定義
resource "aws_instance" "minecraft" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.minecraft_sg.id]
  user_data              = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1

    dnf update -y
    dnf install -y java-17-amazon-corretto wget screen

    mkdir -p /home/ec2-user/minecraft
    cd /home/ec2-user/minecraft

    # Minecraft 1.20.1 server JAR
    wget https://piston-data.mojang.com/v1/objects/84194a2f286ef7c14ed7ce0090dba59902951553/server.jar -O server.jar

    echo "eula=true" > eula.txt

    # 権限付与
    chown -R ec2-user:ec2-user /home/ec2-user/minecraft

    # screenセッションをec2-userで起動する
    su - ec2-user -c "cd /home/ec2-user/minecraft && screen -dmS minecraft java -Xmx2G -Xms1G -jar server.jar nogui"

    echo "Minecraft server started." >> /home/ec2-user/minecraft/setup.log
  EOF

  tags = {
    Name = "Minecraft Server"
  }
}


