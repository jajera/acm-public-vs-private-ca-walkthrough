output "vpc_id" {
  value = aws_vpc.lab.id
}

output "vpc_cidr" {
  value = var.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnets (ALB, NAT)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnets (EC2 app and clients; egress via NAT)."
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.lab.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.lab.id
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "internal_alb_security_group_id" {
  description = "Internal ALB for Private CA ACM path."
  value       = aws_security_group.internal_alb.id
}

output "public_web_security_group_id" {
  value = aws_security_group.public_web.id
}

output "private_web_security_group_id" {
  value = aws_security_group.private_web.id
}

output "clients_security_group_id" {
  value = aws_security_group.clients.id
}

output "ssm_instance_profile_name" {
  value = aws_iam_instance_profile.ssm.name
}

output "ami_id" {
  value = data.aws_ami.al2023.id
}

output "name_prefix" {
  value = var.name_prefix
}

output "aws_region" {
  value = var.aws_region
}
