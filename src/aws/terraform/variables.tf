variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for Amazon Linux 2023 (Arm64)"
  type        = string
}

variable "public_ip" {
  description = "Public IP address"
  type        = list(string)
}

variable "instance_id" {
  description = "EC2 instance ID"
  type        = string
}

variable "hosted_zone_id" {
  description = "Hosted zone ID"
  type        = string
}

variable "dns_name" {
  description = "DNS name"
  type        = string
}

variable "server_file_key" {
  description = "Server file key"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name"
  type        = string
}
