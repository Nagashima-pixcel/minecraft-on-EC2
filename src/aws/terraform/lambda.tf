# Lambda用IAMロール
resource "aws_iam_role" "lambda_route53_role" {
  name = "lambda-route53-updater-role"

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
}

# Lambda用IAMポリシー
resource "aws_iam_policy" "lambda_route53_policy" {
  name        = "lambda-route53-updater-policy"
  description = "Policy for Lambda to update Route53 records and manage EC2"

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
          "ec2:DescribeInstances"
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
}

# IAMポリシーをロールにアタッチ
resource "aws_iam_role_policy_attachment" "lambda_route53_policy_attachment" {
  role       = aws_iam_role.lambda_route53_role.name
  policy_arn = aws_iam_policy.lambda_route53_policy.arn
}

# Lambda関数用のZIPファイル
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/update_route53_record.py"
  output_path = "${path.module}/../lambda/update_route53_record.zip"
}

# Lambda関数
resource "aws_lambda_function" "route53_updater" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "minecraft-route53-updater"
  role            = aws_iam_role.lambda_route53_role.arn
  handler         = "update_route53_record.lambda_handler"
  runtime         = "python3.12"
  timeout         = 300
  memory_size     = 256
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      INSTANCE_ID     = var.instance_id
      HOSTED_ZONE_ID  = var.hosted_zone_id
      DNS_NAME        = var.dns_name
    }
  }

  tags = {
    Name = "minecraft-route53-updater"
  }
}

# EventBridgeルール（EC2起動時にLambdaをトリガー）
resource "aws_cloudwatch_event_rule" "ec2_start_rule" {
  name        = "minecraft-ec2-start-rule"
  description = "Trigger Lambda when Minecraft EC2 instance starts"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state       = ["running"]
      instance-id = [var.instance_id]
    }
  })
}

# EventBridgeターゲット（Lambdaを呼び出し）
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.ec2_start_rule.name
  target_id = "TriggerLambdaFunction"
  arn       = aws_lambda_function.route53_updater.arn
}

# LambdaがEventBridgeから呼び出されることを許可
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.route53_updater.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2_start_rule.arn
} 
