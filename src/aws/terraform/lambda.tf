# =============================================================================
# Minecraft Server Auto Management Lambda Function
# EC2自動起動・Route53 DNS更新・監視システム統合
# =============================================================================

# Minecraft自動管理用IAMロール
resource "aws_iam_role" "minecraft_auto_manager_role" {
  name = "minecraft-auto-manager-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "minecraft-auto-manager"
  }
}

# Minecraft自動管理用IAMポリシー
resource "aws_iam_policy" "minecraft_auto_manager_policy" {
  name        = "minecraft-auto-manager-policy"
  description = "Policy for Minecraft server auto management (EC2, Route53, EventBridge)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:DescribeInstances",
          "events:DescribeRule"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/${var.hosted_zone_id}"
      }
    ]
  })

  tags = {
    Name = "minecraft-auto-manager"
  }
}

# IAMポリシーをロールにアタッチ
resource "aws_iam_role_policy_attachment" "minecraft_auto_manager_policy_attachment" {
  role       = aws_iam_role.minecraft_auto_manager_role.name
  policy_arn = aws_iam_policy.minecraft_auto_manager_policy.arn
}

# Minecraft自動管理Lambda関数用ZIPファイル
data "archive_file" "minecraft_auto_manager_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/minecraft_auto_manager.py"
  output_path = "${path.module}/../lambda/minecraft_auto_manager.zip"
}

# Minecraft自動管理Lambda関数
resource "aws_lambda_function" "minecraft_auto_manager" {
  filename         = data.archive_file.minecraft_auto_manager_zip.output_path
  function_name    = "minecraft-auto-manager"
  role            = aws_iam_role.minecraft_auto_manager_role.arn
  handler         = "minecraft_auto_manager.lambda_handler"
  runtime         = "python3.12"
  timeout         = 300
  memory_size     = 256
  source_code_hash = data.archive_file.minecraft_auto_manager_zip.output_base64sha256

  environment {
    variables = {
      INSTANCE_ID          = var.instance_id
      HOSTED_ZONE_ID       = var.hosted_zone_id
      DNS_NAME            = var.dns_name
      MINECRAFT_AWS_REGION = var.aws_region
    }
  }

  tags = {
    Name = "minecraft-auto-manager"
  }
}

# EventBridgeルール（EC2起動時にLambdaをトリガー）
resource "aws_cloudwatch_event_rule" "ec2_start_rule" {
  name        = "minecraft-ec2-start-rule"
  description = "Trigger auto manager when Minecraft EC2 instance starts"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state       = ["running"]
      instance-id = [var.instance_id]
    }
  })

  tags = {
    Name = "minecraft-ec2-start-rule"
  }
}

# EventBridgeターゲット（自動管理Lambdaを呼び出し）
resource "aws_cloudwatch_event_target" "minecraft_auto_manager_target" {
  rule      = aws_cloudwatch_event_rule.ec2_start_rule.name
  target_id = "TriggerMinecraftAutoManager"
  arn       = aws_lambda_function.minecraft_auto_manager.arn
}

# LambdaがEventBridgeから呼び出されることを許可
resource "aws_lambda_permission" "allow_eventbridge_auto_manager" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.minecraft_auto_manager.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2_start_rule.arn
} 
