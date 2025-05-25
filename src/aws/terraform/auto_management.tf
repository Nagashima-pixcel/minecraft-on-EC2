# =============================================================================
# Minecraft Server Auto Management System
# 自動起動・停止機能の統合管理
# =============================================================================

# Systems Manager Document（プレイヤ監視・自動停止用）
resource "aws_ssm_document" "minecraft_auto_stop" {
  name          = "minecraft-auto-stop-checker"
  document_type = "Command"
  document_format = "YAML"

  content = <<DOC
schemaVersion: '2.2'
description: Check for active players and stop server if idle
parameters:
  IdleTimeMinutes:
    type: String
    description: Minutes to wait before stopping server when no players are online
    default: '30'
mainSteps:
  - action: aws:runShellScript
    name: checkPlayersAndStop
    inputs:
      timeoutSeconds: '300'
      runCommand:
        - |
          #!/bin/bash
          set -e
          
                     IDLE_TIME_MINUTES="$${IdleTimeMinutes}"
          LOG_FILE="/var/log/minecraft-auto-stop.log"
          MINECRAFT_DIR="/home/ec2-user/DawnCraftEchoesofLegends"
          PLAYER_CHECK_FILE="/tmp/minecraft_player_check"
          
          echo "$(date): Starting player check..." >> $LOG_FILE
          
          # Minecraftサーバが起動しているかチェック
          if ! screen -list | grep -q "minecraft"; then
            echo "$(date): Minecraft server is not running in screen session" >> $LOG_FILE
            exit 0
          fi
          
          # プレイヤ数をチェック
          cd $MINECRAFT_DIR
          PLAYER_COUNT=$(screen -S minecraft -p 0 -X stuff "list^M" && sleep 2 && tail -n 10 logs/latest.log | grep -o "There are [0-9]* of a max" | tail -1 | grep -o "[0-9]*" | head -1 || echo "0")
          
          echo "$(date): Current player count: $PLAYER_COUNT" >> $LOG_FILE
          
          if [ "$PLAYER_COUNT" -eq 0 ]; then
            # プレイヤがいない場合、前回のチェック時刻を確認
            if [ -f "$PLAYER_CHECK_FILE" ]; then
              LAST_CHECK=$(cat $PLAYER_CHECK_FILE)
              CURRENT_TIME=$(date +%s)
              TIME_DIFF=$(( (CURRENT_TIME - LAST_CHECK) / 60 ))
              
              echo "$(date): No players online for $TIME_DIFF minutes" >> $LOG_FILE
              
              if [ $TIME_DIFF -ge $IDLE_TIME_MINUTES ]; then
                echo "$(date): Stopping server due to inactivity" >> $LOG_FILE
                
                # サーバを安全に停止
                screen -S minecraft -p 0 -X stuff "say Server will shutdown in 30 seconds due to inactivity^M"
                sleep 30
                screen -S minecraft -p 0 -X stuff "stop^M"
                sleep 10
                
                # EC2インスタンスを停止
                INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
                aws ec2 stop-instances --instance-ids $INSTANCE_ID --region ${var.aws_region}
                
                echo "$(date): Instance stop command sent" >> $LOG_FILE
              fi
            else
              # 初回チェック時刻を記録
              date +%s > $PLAYER_CHECK_FILE
              echo "$(date): Started idle timer" >> $LOG_FILE
            fi
          else
            # プレイヤがいる場合、チェックファイルを削除
            rm -f $PLAYER_CHECK_FILE
            echo "$(date): Players online, reset idle timer" >> $LOG_FILE
          fi
DOC

  tags = {
    Name = "minecraft-auto-stop-checker"
  }
}

# CloudWatch Events Rule（定期的なプレイヤチェック）
resource "aws_cloudwatch_event_rule" "minecraft_player_check" {
  name                = "minecraft-player-check-rule"
  description         = "Trigger player check every 10 minutes"
  schedule_expression = "rate(10 minutes)"

  tags = {
    Name = "minecraft-player-check"
  }
}

# CloudWatch Events Target（Systems Manager Document実行）
resource "aws_cloudwatch_event_target" "minecraft_player_check_target" {
  rule      = aws_cloudwatch_event_rule.minecraft_player_check.name
  target_id = "MinecraftPlayerCheckTarget"
  arn       = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:document/${aws_ssm_document.minecraft_auto_stop.name}"
  role_arn  = aws_iam_role.minecraft_auto_management_role.arn

  run_command_targets {
    key    = "InstanceIds"
    values = [var.instance_id]
  }

  input = jsonencode({
    DocumentName = aws_ssm_document.minecraft_auto_stop.name
    Parameters = {
      IdleTimeMinutes = ["30"]
    }
  })
}

# 現在のAWSアカウントIDを取得
data "aws_caller_identity" "current" {}

# 自動管理用IAMロール
resource "aws_iam_role" "minecraft_auto_management_role" {
  name = "minecraft-auto-management-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "minecraft-auto-management"
  }
}

# 自動管理用IAMポリシー
resource "aws_iam_policy" "minecraft_auto_management_policy" {
  name        = "minecraft-auto-management-policy"
  description = "Policy for Minecraft server auto management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:DescribeInstanceInformation",
          "ssm:ListCommandInvocations"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:document/${aws_ssm_document.minecraft_auto_stop.name}",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${var.instance_id}"
        ]
      }
    ]
  })

  tags = {
    Name = "minecraft-auto-management"
  }
}

# IAMポリシーをロールにアタッチ
resource "aws_iam_role_policy_attachment" "minecraft_auto_management_attachment" {
  role       = aws_iam_role.minecraft_auto_management_role.name
  policy_arn = aws_iam_policy.minecraft_auto_management_policy.arn
}

# EC2インスタンスに自動停止権限を追加
resource "aws_iam_policy" "ec2_auto_stop_policy" {
  name        = "ec2-minecraft-auto-stop-policy"
  description = "Policy for EC2 to stop itself when idle"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:StopInstances",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Name" = "Minecraft Server"
          }
        }
      }
    ]
  })

  tags = {
    Name = "ec2-auto-stop"
  }
}

# EC2ロールに自動停止ポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "ec2_auto_stop_attachment" {
  role       = aws_iam_role.ec2_minecraft_role.name
  policy_arn = aws_iam_policy.ec2_auto_stop_policy.arn
} 
