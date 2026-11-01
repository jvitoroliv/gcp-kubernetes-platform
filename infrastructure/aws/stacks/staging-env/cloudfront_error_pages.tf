# ======================================================================
# CLOUDFRONT - COMPLETE ERROR PAGE COVERAGE
# ======================================================================
# CloudFront distribution with custom error pages for ALL error scenarios
# including target group failures (502/503/504)
#
# This is the ONLY way to show custom error pages when ECS targets fail
# ======================================================================

# S3 Bucket for error pages
module "error_pages_bucket" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/s3-bucket?ref=main"

  # Only create when CloudFront error pages enabled
  count = var.enable_cloudfront_error_pages ? 1 : 0

  name = "gameplatform-${var.environment}-error-pages-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.tags, {
    Purpose = "CloudFront-Error-Pages"
  })
}

# Upload maintenance.html to S3
resource "aws_s3_object" "maintenance_page" {
  count = var.enable_cloudfront_error_pages ? 1 : 0

  bucket       = module.error_pages_bucket[0].id
  key          = "maintenance.html"
  source       = "${path.module}/maintenance.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/maintenance.html")

  tags = local.tags
}

# CloudFront Origin Access Identity for S3
resource "aws_cloudfront_origin_access_identity" "error_pages" {
  count = var.enable_cloudfront_error_pages ? 1 : 0

  comment = "OAI for GamePlatform error pages bucket"
}

# S3 Bucket Policy - Allow CloudFront to read error pages
resource "aws_s3_bucket_policy" "error_pages_cloudfront" {
  count = var.enable_cloudfront_error_pages ? 1 : 0

  bucket = module.error_pages_bucket[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAI"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.error_pages[0].iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${module.error_pages_bucket[0].arn}/*"
      }
    ]
  })
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  count = var.enable_cloudfront_error_pages ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "GamePlatform ${var.environment} - CloudFront with custom error pages"
  default_root_object = ""
  price_class         = "PriceClass_100" # US, Canada, Europe

  # Aliases (custom domains)
  aliases = ["app.${var.domain_name}"]

  # Origin 1: ALB (primary)
  origin {
    domain_name = data.aws_lb.shared.dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_keepalive_timeout = 60
      origin_read_timeout      = 60
    }

    # Forward headers to ALB
    custom_header {
      name  = "X-CloudFront-Forwarded"
      value = "true"
    }
  }

  # Origin 2: S3 bucket with error pages
  origin {
    domain_name = module.error_pages_bucket[0].regional_domain_name
    origin_id   = "error-pages-s3"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.error_pages[0].cloudfront_access_identity_path
    }
  }

  # Ordered cache behavior for maintenance.html (S3 origin)
  ordered_cache_behavior {
    path_pattern     = "/maintenance.html"
    target_origin_id = "error-pages-s3"

    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    # Cache for 10 seconds
    min_ttl     = 0
    default_ttl = 10
    max_ttl     = 10

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # Default cache behavior (forward to ALB)
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "alb-origin"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    # Cache policy: CachingDisabled (forward all headers/cookies/query strings)
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # Origin request policy: AllViewer
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  }

  # Custom error responses - REDIRECT ALL ERRORS TO MAINTENANCE PAGE
  custom_error_response {
    error_code            = 502
    response_code         = 503
    response_page_path    = "/maintenance.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 503
    response_code         = 503
    response_page_path    = "/maintenance.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 504
    response_code         = 503
    response_page_path    = "/maintenance.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 500
    response_code         = 503
    response_page_path    = "/maintenance.html"
    error_caching_min_ttl = 10
  }

  # SSL Certificate (ACM certificate for *.gameplatform.example.com from us-east-1)
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cloudfront[0].certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Geo restriction (optional - remove if global access needed)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = merge(local.tags, {
    Purpose = "CloudFront-Error-Handling"
  })
}

# Update Route53 to point to CloudFront (instead of ALB directly)
# Uses allow_overwrite to update existing DNS record without deletion
resource "aws_route53_record" "lobby_cloudfront" {
  count = var.enable_cloudfront_error_pages ? 1 : 0

  zone_id         = data.aws_route53_zone.main.zone_id
  name            = "app"
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.main[0].domain_name
    zone_id                = aws_cloudfront_distribution.main[0].hosted_zone_id
    evaluate_target_health = false
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_cloudfront_distribution.main
  ]
}

# Output CloudFront URL
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = var.enable_cloudfront_error_pages ? aws_cloudfront_distribution.main[0].id : null
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = var.enable_cloudfront_error_pages ? aws_cloudfront_distribution.main[0].domain_name : null
}
