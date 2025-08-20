output "bucket_name" {
  value = aws_s3_bucket.static.bucket
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.main.domain_name}"
}