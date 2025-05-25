# =============================================================================
# Player-Triggered Auto Start System
# プレイヤ接続時の自動起動システム
# =============================================================================

# プレイヤ起動用Lambda関数
resource "aws_lambda_function" "player_start_trigger" {
  filename         = data.archive_file.player_trigger_zip.output_path
  function_name    = "minecraft-player-start-trigger"
  role            = aws_iam_role.player_trigger_role.arn
  handler         = "player_trigger.lambda_handler"
  runtime         = "python3.12"
  timeout         = 300
  memory_size     = 256
  source_code_hash = data.archive_file.player_trigger_zip.output_base64sha256

  environment {
    variables = {
      INSTANCE_ID          = var.instance_id
      HOSTED_ZONE_ID       = var.hosted_zone_id
      DNS_NAME            = var.dns_name
      MINECRAFT_AWS_REGION = var.aws_region
    }
  }

  tags = {
    Name = "minecraft-player-start-trigger"
  }
}

# Lambda Function URLの設定（API Gateway代替）
resource "aws_lambda_function_url" "player_start_url" {
  function_name      = aws_lambda_function.player_start_trigger.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["GET", "POST"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["date", "keep-alive"]
    max_age          = 86400
  }

  depends_on = [aws_lambda_function.player_start_trigger]
}

# プレイヤ起動用Lambda関数のZIPファイル
data "archive_file" "player_trigger_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/player_trigger.py"
  output_path = "${path.module}/../lambda/player_trigger.zip"
}

# プレイヤ起動用IAMロール
resource "aws_iam_role" "player_trigger_role" {
  name = "minecraft-player-trigger-role"

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
    Name = "minecraft-player-trigger"
  }
}

# プレイヤ起動用IAMポリシー
resource "aws_iam_policy" "player_trigger_policy" {
  name        = "minecraft-player-trigger-policy"
  description = "Policy for player-triggered server startup"

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
          "ec2:DescribeInstanceStatus"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations"
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
    Name = "minecraft-player-trigger"
  }
}

# IAMポリシーをロールにアタッチ
resource "aws_iam_role_policy_attachment" "player_trigger_policy_attachment" {
  role       = aws_iam_role.player_trigger_role.name
  policy_arn = aws_iam_policy.player_trigger_policy.arn
}

# サーバ状態確認用Lambda関数
resource "aws_lambda_function" "server_status_checker" {
  filename         = data.archive_file.status_checker_zip.output_path
  function_name    = "minecraft-server-status-checker"
  role            = aws_iam_role.player_trigger_role.arn
  handler         = "status_checker.lambda_handler"
  runtime         = "python3.12"
  timeout         = 30
  memory_size     = 128
  source_code_hash = data.archive_file.status_checker_zip.output_base64sha256

  environment {
    variables = {
      INSTANCE_ID          = var.instance_id
      DNS_NAME            = var.dns_name
      MINECRAFT_AWS_REGION = var.aws_region
    }
  }

  tags = {
    Name = "minecraft-server-status-checker"
  }
}

# サーバ状態確認用Lambda Function URL
resource "aws_lambda_function_url" "server_status_url" {
  function_name      = aws_lambda_function.server_status_checker.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["GET"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["date", "keep-alive"]
    max_age          = 86400
  }

  depends_on = [aws_lambda_function.server_status_checker]
}

# サーバ状態確認用Lambda関数のZIPファイル
data "archive_file" "status_checker_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/status_checker.py"
  output_path = "${path.module}/../lambda/status_checker.zip"
} 
