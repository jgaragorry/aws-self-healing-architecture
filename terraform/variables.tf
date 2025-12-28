variable "aws_region" {
  description = "Región de AWS"
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente"
  default     = "Production"
}

variable "vpc_cidr" {
  description = "CIDR Block para la VPC"
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  default     = "t3.micro"
}

variable "db_password" {
  description = "Password para la base de datos RDS"
  type        = string
  sensitive   = true
}
