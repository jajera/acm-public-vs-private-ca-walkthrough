output "public_url" {
  description = "Public ACM path URL."
  value       = "https://${var.public_hostname}"
}

output "public_hostname" {
  value = var.public_hostname
}

output "public_certificate_arn" {
  value = aws_acm_certificate.public.arn
}

output "alb_dns_name" {
  value = aws_lb.public.dns_name
}

output "alb_zone_id" {
  value = aws_lb.public.zone_id
}

output "public_web_instance_id" {
  value = aws_instance.public_web.id
}
