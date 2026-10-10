output "private_url" {
  description = "Private CA path URL."
  value       = "https://${var.private_hostname}"
}

output "private_hostname" {
  value = var.private_hostname
}

output "private_tls_mode" {
  description = "alb_acm or nginx_export."
  value       = var.private_tls_mode
}

output "private_ca_arn" {
  description = "AWS Private CA ARN — destroy promptly after the lab."
  value       = aws_acmpca_certificate_authority.root.arn
}

output "ca_certificate_pem" {
  description = "Root CA PEM for trust distribution (public material)."
  value       = aws_acmpca_certificate.root.certificate
  sensitive   = true
}

output "private_web_private_ip" {
  value = aws_instance.private_web.private_ip
}

output "private_web_instance_id" {
  value = aws_instance.private_web.id
}

output "private_hosted_zone_id" {
  value = aws_route53_zone.private.zone_id
}

output "acm_private_certificate_arn" {
  description = "ACM private certificate ARN (alb_acm mode only)."
  value       = local.mode_alb ? aws_acm_certificate.private[0].arn : null
}

output "internal_alb_dns_name" {
  description = "Internal ALB DNS name (alb_acm mode only)."
  value       = local.mode_alb ? aws_lb.internal[0].dns_name : null
}

output "private_leaf_secret_arn" {
  description = "Secrets Manager leaf ARN (nginx_export mode only)."
  value       = local.mode_nginx ? aws_secretsmanager_secret.private_leaf[0].arn : null
}

output "ssm_configure_association_id" {
  description = "State Manager association for nginx leaf (nginx_export mode only)."
  value       = local.mode_nginx ? aws_ssm_association.configure_private_web[0].association_id : null
}
