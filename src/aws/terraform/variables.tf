variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.large"
}

variable "ami_id" {
  description = "AMI ID for Amazon Linux 2023 (Arm64)"
  type        = string
}
