terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.28.0"
    }
  }
  required_version = "~> 0.14"

  backend "remote" {
    organization = "tnorlund"

    workspaces {
      name = "airspace-screening"
    }
  }
}

/**
 * The AWS provider should be handled by ENV vars. 
 */
variable "aws_region" {
  type        = string
  description = "The AWS region"
  default     = "us-east-1"
}

provider "aws" {
  region = var.aws_region
}

/**
 * The Glue database will link the different tables together
 */
resource "aws_glue_catalog_database" "database" {
  name = "airspace"
}

/**
 * Create S3 buckets and crawlers to upload the '.csv' files and crawl them for 
 * metadata.
 */
module "route" {
  source = "./glue-bucket"
  bucket_name = "airspace-route"
  csv_file = "./data/delivery_route_segments.csv"
  table_name = "route"
  database_name = aws_glue_catalog_database.database.name
}
module "searches" {
  source = "./glue-bucket"
  bucket_name = "airspace-searches"
  csv_file = "./data/driving_searches.csv"
  table_name = "searches"
  database_name = aws_glue_catalog_database.database.name
}
module "end_addresses" {
  source = "./glue-bucket"
  bucket_name = "airspace-end-addresses"
  csv_file = "./data/end_addresses.csv"
  table_name = "end_addresses"
  database_name = aws_glue_catalog_database.database.name
}
module "start_addresses" {
  source = "./glue-bucket"
  bucket_name = "airspace-start-addresses"
  csv_file = "./data/start_addresses.csv"
  table_name = "start_addresses"
  database_name = aws_glue_catalog_database.database.name
}
module "orders" {
  source = "./glue-bucket"
  bucket_name = "airspace-orders"
  csv_file = "./data/orders.csv"
  table_name = "orders"
  database_name = aws_glue_catalog_database.database.name
}

/**
 * An S3 bucket is used to hold normalized data.
 */
resource "aws_s3_bucket" "output" {
  bucket = "airspace-output"
  acl    = "private"
}

/**
 * Set a policy to allow Athena to access the buckets
 */
data "aws_iam_policy_document" "glue" {
  statement {
    effect = "Allow"
    actions = [
      "s3:*",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
      "logs:CreateLogStream"
    ]
    resources = [
      module.route.bucket_arn,
      "${module.route.bucket_arn}/*",
      module.searches.bucket_arn,
      "${module.searches.bucket_arn}/*",
      module.end_addresses.bucket_arn,
      "${module.end_addresses.bucket_arn}/*",
      module.start_addresses.bucket_arn,
      "${module.start_addresses.bucket_arn}/*",
      module.orders.bucket_arn,
      "${module.orders.bucket_arn}/*",
      aws_s3_bucket.output.arn,
      "${aws_s3_bucket.output.arn}/*",
      "arn:aws:logs:*:*:*",
      "arn:aws:glue:**"
    ]
    sid = "authCommitId"
  }
}
resource "aws_iam_role" "glue" {
  name = "glue_join_role"

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

/**
 * The Python Lambda Layer should be uploaded to an S3 bucket.
 */
module "python_layer" {
  source      = "./LambdaLayer"
  type        = "python"
  developer   = "Tyler Norlund"
  bucket_name = "tf-cloud"
}

module "processor" {
  source = "./lambda"
  bucket_name = "tf-cloud"
  python_layer_arn = module.python_layer.arn
  developer = "Tyler Norlund"
}