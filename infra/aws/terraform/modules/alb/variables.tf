variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ALB"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for ALB"
  type        = list(string)
}

variable "container_port" {
  description = "Container port"
  type        = number
}

# variable "certificate_arn" {
#   description = "ACM certificate ARN for HTTPS"
#   type        = string
#   default     = ""
# }
