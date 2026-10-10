provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "acm-public-vs-private-ca-walkthrough"
      ManagedBy = "terraform"
      Stage     = "04-trust"
    }
  }
}
