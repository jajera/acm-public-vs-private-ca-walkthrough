variable "aws_region" {
  type        = string
  description = "Region for the lab (ACM public cert must match the ALB Region)."
  default     = "ap-southeast-2"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "acm-lab"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR."
  default     = "10.42.0.0/16"
}

variable "route53_zone_id" {
  type        = string
  description = "Public hosted zone ID in this account (ACM validation CNAMEs + ALB alias)."
}


variable "public_hostname" {
  type        = string
  description = "Public FQDN served by the ALB with an ACM public certificate."
  default     = "demo.johna.kiwi"
}

variable "private_hostname" {
  type        = string
  description = "Private FQDN for the Private CA path (internal ALB or nginx)."
  default     = "app.internal.johna.kiwi"
}

variable "private_tls_mode" {
  type        = string
  description = "Passed through shared tfvars; used by stage 03."
  default     = "alb_acm"

  validation {
    condition     = contains(["alb_acm", "nginx_export"], var.private_tls_mode)
    error_message = "private_tls_mode must be alb_acm or nginx_export."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for lab hosts."
  default     = "t3.micro"
}
