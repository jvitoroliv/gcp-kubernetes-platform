# ======================================================================
# CLOUDFRONT CERTIFICATE - US-EAST-1 REQUIREMENT
# ======================================================================
# CloudFront is a global service and REQUIRES ACM certificates in us-east-1
# This creates a duplicate certificate in us-east-1 ONLY for CloudFront use
# Your main infrastructure stays in sa-east-1
# ======================================================================

# ACM Certificate for CloudFront (MUST be in us-east-1)
resource "aws_acm_certificate" "cloudfront" {
  count = var.enable_cloudfront_error_pages ? 1 : 0

  provider = aws.us_east_1 # Force us-east-1 for CloudFront

  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.tags, {
    Purpose = "CloudFront-Certificate"
    Region  = "us-east-1"
  })
}

# DNS validation records for CloudFront certificate
resource "aws_route53_record" "cloudfront_cert_validation" {
  for_each = var.enable_cloudfront_error_pages ? {
    for dvo in aws_acm_certificate.cloudfront[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "cloudfront" {
  count = var.enable_cloudfront_error_pages ? 1 : 0

  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cloudfront_cert_validation : record.fqdn]

  timeouts {
    create = "15m"
  }
}

# Output certificate ARN
output "cloudfront_certificate_arn" {
  description = "ARN of CloudFront certificate in us-east-1"
  value       = var.enable_cloudfront_error_pages ? aws_acm_certificate.cloudfront[0].arn : null
}
