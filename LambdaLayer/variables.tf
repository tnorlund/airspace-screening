variable "type" {
  type        = string
  description = "Whether the layer is python or nodejs"
}

variable "developer" {
  type        = string
  description = "The name of the developer making the change"
}

variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket used to hold the uploaded code"
}