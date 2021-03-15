/**
 * Creates a layer using the '.zip' found in S3.
 */
resource "aws_lambda_layer_version" "layer" {
  layer_name = var.type == "nodejs" ? "analytics_js" : "analytics_python"
  s3_bucket  = var.bucket_name
  s3_key     = var.type == "nodejs" ? "nodejs.zip" : "python.zip"

  description         = var.type == "nodejs" ? "Node Framework used to access DynamoDB" : "Python Framework used to access DynamoDB"
  compatible_runtimes = var.type == "nodejs" ? ["nodejs12.x"] : ["python3.8"]
}

