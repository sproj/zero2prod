variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (e.g. dev, production)"
  type        = string
  default     = "production"
}

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "zero2prod"
}

variable "ecr_repository_url" {
  description = "URL of the ECR repository containing your application image"
  type        = string
}

variable "container_port" {
  description = "Port the container exposes"
  type        = number
  default     = 8000
}

variable "desired_count" {
  description = "Number of instances of the task to run"
  type        = number
  default     = 1
}

variable "your_ip" {
  description = "Your IP address for security group ingress"
  type        = string
  default     = "185.46.252.133"  # Better to restrict to your actual IP
}

variable "cpu" {
  description = "CPU units for the Fargate task (1024 = 1 vCPU)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory for the Fargate task in MiB"
  type        = number
  default     = 512
}