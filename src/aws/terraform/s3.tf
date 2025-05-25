# S3バケット（Minecraftサーバファイル用）
resource "aws_s3_bucket" "minecraft_server_files" {
  bucket = "${var.s3_bucket_name}"

  tags = {
    Name = "minecraft-server-files"
  }
}

# バケット名の一意性確保用ランダム文字列
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# バケットの公開アクセスをブロック
resource "aws_s3_bucket_public_access_block" "minecraft_server_files" {
  bucket = aws_s3_bucket.minecraft_server_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 既存のサーバファイルを参照（大きなファイルは事前アップロード済み）
data "aws_s3_object" "minecraft_server_zip" {
  bucket = aws_s3_bucket.minecraft_server_files.id
  key    = "dawncraft-server.zip"
} 
