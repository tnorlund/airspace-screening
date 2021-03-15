data "aws_iam_policy_document" "lambda" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
      "logs:CreateLogStream"
    ]
    resources = [
      "arn:aws:logs:*"
    ]
    sid = "lambdaAirspaceProcessor"
  }
}
resource "aws_iam_role" "lambda" {
  name = "lambda_airspace_processor"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy" "lambda_processor" {
  policy = data.aws_iam_policy_document.lambda.json
  role   = aws_iam_role.lambda.id
}
/**
 * Get the object from S3 to see if it needs to be applied.
 */
data "aws_s3_bucket_object" "lambda_processor" {
  bucket = var.bucket_name
  key    = "airspace_processor.zip"
}
resource "aws_lambda_function" "lambda_processor" {
  s3_bucket        = var.bucket_name
  s3_key           = "airspace_processor.zip"
  function_name    = "airspace_processor"
  role             = aws_iam_role.lambda.arn
  handler          = "airspace_processor.airspace_processor"
  source_code_hash = data.aws_s3_bucket_object.lambda_processor.body
  runtime          = "python3.8"
  layers           = [var.python_layer_arn]
  memory_size      = 256
  timeout          = 60
  tags = {
    Project   = "Airspace"
    Developer = var.developer
  }
}