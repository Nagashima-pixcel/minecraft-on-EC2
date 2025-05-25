# =============================================================================
# Terraform Outputs
# デプロイ後の重要な情報を出力
# =============================================================================

# プレイヤ起動用Lambda Function URL
output "player_start_url" {
  description = "URL for players to start the Minecraft server"
  value       = aws_lambda_function_url.player_start_url.function_url
}

# サーバ状態確認用Lambda Function URL
output "server_status_url" {
  description = "URL to check Minecraft server status"
  value       = aws_lambda_function_url.server_status_url.function_url
}

# EC2インスタンス情報
output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.minecraft.id
}

output "ec2_public_ip" {
  description = "EC2 instance public IP"
  value       = aws_instance.minecraft.public_ip
}

# DNS情報
output "minecraft_server_dns" {
  description = "Minecraft server DNS name"
  value       = var.dns_name
}

# S3バケット情報
output "s3_bucket_name" {
  description = "S3 bucket for server files"
  value       = aws_s3_bucket.minecraft_server_files.bucket
}

# Lambda関数情報
output "lambda_functions" {
  description = "Lambda function names and ARNs"
  value = {
    auto_manager = {
      name = aws_lambda_function.minecraft_auto_manager.function_name
      arn  = aws_lambda_function.minecraft_auto_manager.arn
    }
    player_trigger = {
      name = aws_lambda_function.player_start_trigger.function_name
      arn  = aws_lambda_function.player_start_trigger.arn
    }
    status_checker = {
      name = aws_lambda_function.server_status_checker.function_name
      arn  = aws_lambda_function.server_status_checker.arn
    }
  }
}

# 自動管理システム情報
output "auto_management_info" {
  description = "Auto management system information"
  value = {
    ssm_document_name = aws_ssm_document.minecraft_auto_stop.name
    player_check_rule = aws_cloudwatch_event_rule.minecraft_player_check.name
    ec2_start_rule    = aws_cloudwatch_event_rule.ec2_start_rule.name
  }
}

# プレイヤ向け情報
output "player_instructions" {
  description = "Instructions for players"
  value = {
    server_launcher_url = aws_lambda_function_url.player_start_url.function_url
    minecraft_address   = var.dns_name
    message            = "Use the server_launcher_url to start the server, then connect to minecraft_address"
  }
} 
