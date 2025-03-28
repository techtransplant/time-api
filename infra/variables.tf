# Variables
variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "api_name" {
  description = "The name of the API"
  type        = string
  default     = "time-api"
}

variable "image_tag" {
  description = "The tag to use for the Docker image"
  type        = string
  default     = "main"
}

variable "container_port" {
  description = "The port to use for the container"
  type        = number
  default     = 8000
}

variable "host_port" {
  description = "The port to use for the host"
  type        = number
  default     = 8000
}

variable "desired_count" {
  description = "The desired count of task instances"
  type        = number
  default     = 2
}
