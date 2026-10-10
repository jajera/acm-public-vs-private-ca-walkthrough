output "ca_s3_uri" {
  description = "Published CA PEM (trust anchor only)."
  value       = "s3://${aws_s3_bucket.ca_trust.id}/${aws_s3_object.ca_pem.key}"
}

output "ca_trust_bucket" {
  value = aws_s3_bucket.ca_trust.id
}

output "managed_client_instance_id" {
  value = aws_instance.client_managed.id
}

output "unmanaged_client_instance_id" {
  value = aws_instance.client_unmanaged.id
}

output "ssm_association_id" {
  value = aws_ssm_association.install_ca_trust.id
}

output "private_url" {
  description = "Convenience mirror of 03-private private_url."
  value       = local.private.private_url
}
