output "alb_public_url" {
  description = "Public URL"
  value       = aws_lb.alb.dns_name
}
