/**
 * An S3 bucket is used to hold the csv file. This is then used by Glue to 
 * crawl.
 */
resource "aws_s3_bucket" "glue" {
  bucket = var.bucket_name
  acl    = "private"
}

/**
 * Upload the file as an object to S3.
 */
resource "aws_s3_bucket_object" "object" {
  bucket = aws_s3_bucket.glue.id
  key    = "file.csv"
  acl    = "private"
  source = var.csv_file
  etag   = filemd5(var.csv_file)
}

/**
 * Set a policy to allow the glue crawler to crawl the S3 Bucket.
 */
data "aws_iam_policy_document" "glue" {
  statement {
    effect = "Allow"
    actions = [
      "glue:*",
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
      "logs:CreateLogStream"
    ]
    resources = [
      aws_s3_bucket.glue.arn,
      "${aws_s3_bucket.glue.arn}/*",
      "arn:aws:logs:*:*:*",
      "arn:aws:glue:**"
    ]
    sid = "authCommitId"
  }
}
resource "aws_iam_role" "glue" {
  name = "glue_role_${var.table_name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy" "glue" {
  policy = data.aws_iam_policy_document.glue.json
  role   = aws_iam_role.glue.id
}

resource "aws_glue_crawler" "table" {
  database_name = var.database_name
  name          = var.table_name
  role          = aws_iam_role.glue.id
  s3_target {
    path = "s3://${aws_s3_bucket.glue.bucket}"
  }
}
