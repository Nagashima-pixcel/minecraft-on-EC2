terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.98.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.2"
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

# EC2用IAMロール（S3アクセス権限付き）
resource "aws_iam_role" "ec2_minecraft_role" {
  name = "ec2-minecraft-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# EC2用IAMポリシー（S3アクセス）
resource "aws_iam_policy" "ec2_s3_policy" {
  name        = "ec2-minecraft-s3-policy"
  description = "Policy for EC2 to access Minecraft server files in S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.minecraft_server_files.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssm:SendCommand",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations",
          "ssm:DescribeInstanceInformation",
          "ssm:GetCommandInvocation",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAMポリシーをロールにアタッチ
resource "aws_iam_role_policy_attachment" "ec2_s3_policy_attachment" {
  role       = aws_iam_role.ec2_minecraft_role.name
  policy_arn = aws_iam_policy.ec2_s3_policy.arn
}

# EC2インスタンスプロファイル
resource "aws_iam_instance_profile" "ec2_minecraft_profile" {
  name = "ec2-minecraft-profile"
  role = aws_iam_role.ec2_minecraft_role.name
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
  iam_instance_profile   = aws_iam_instance_profile.ec2_minecraft_profile.name
  
  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -e

    echo "=== DawnCraft Server Setup Started ===" >> /home/ec2-user/setup.log

    # システム更新とパッケージインストール
    echo "System update and package installation..." >> /home/ec2-user/setup.logs
    dnf update -y
    dnf install -y java-17-amazon-corretto wget screen unzip curl --allowerasing

    # ec2-userのホームディレクトリでMinecraftサーバセットアップ
    cd /home/ec2-user

    # S3からDawnCraftサーバファイルをダウンロード
    echo "Downloading DawnCraft server files from S3..." >> /home/ec2-user/setup.log
    aws s3 cp s3://${aws_s3_bucket.minecraft_server_files.bucket}/dawncraft-server.zip ./dawncraft-server.zip

    # ZIPファイルを展開
    echo "Extracting DawnCraft server files..." >> /home/ec2-user/setup.log
    unzip -q dawncraft-server.zip
    rm dawncraft-server.zip

    # DawnCraftEchoesofLegendsディレクトリに移動
    cd /home/ec2-user/DawnCraftEchoesofLegends

    # 権限設定
    chown -R ec2-user:ec2-user /home/ec2-user/
    
    # start.shに実行権限を付与
    chmod +x start.sh

    # variables.txtのJavaメモリ設定を変更（t4g.largeの8GB RAMに対応）
    echo "Updating Java memory settings for t4g.large..." >> /home/ec2-user/setup.log
    sed -i 's/JAVA_ARGS="-Xmx4G -Xms4G"/JAVA_ARGS="-Xmx6G -Xms4G"/' variables.txt

    # EULAに同意
    echo "eula=true" > eula.txt

    # DawnCraftサーバを非対話モードで起動（start.shを使用）
    echo "Starting DawnCraft server using start.sh..." >> /home/ec2-user/setup.log
    sudo -u ec2-user bash -c "cd /home/ec2-user/DawnCraftEchoesofLegends && echo 'I agree' | timeout 300 bash start.sh" || true

    # サーバが完全に起動したらバックグラウンドで再起動
    echo "Restarting server in background..." >> /home/ec2-user/setup.log
    sudo -u ec2-user bash -c "cd /home/ec2-user/DawnCraftEchoesofLegends && screen -dmS minecraft bash start.sh" || true

    echo "=== DawnCraft server setup completed ===" >> /home/ec2-user/setup.log
  EOF

  tags = {
    Name = "Minecraft Server"
  }
}


