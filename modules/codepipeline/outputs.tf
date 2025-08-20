output "source_bucket" {
  value = aws_s3_bucket.source.bucket
}

output "pipeline_name" {
  value = aws_codepipeline.wordpress.name
}