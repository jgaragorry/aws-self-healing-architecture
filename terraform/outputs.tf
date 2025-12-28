output "alb_dns_name" {
  description = "DNS del Load Balancer (Aquí verás tu web)"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "Endpoint de conexión a la base de datos"
  value       = aws_db_instance.default.address
}

output "asg_name" {
  description = "Nombre del Auto Scaling Group"
  value       = aws_autoscaling_group.main.name
}
