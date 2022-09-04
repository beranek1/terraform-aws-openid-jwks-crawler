variable "prefix" {
  type        = string
  description = "Naming prefix for resources created by this module. (Prefix separator included)"
  default     = "openid_jwks_crawler_"
}

variable "oidc_providers" {
  type        = list(string)
  description = "List of OIDC (OpenID Connect) providers to be crawled (i.e. login.live.com)"
}

variable "src_bucket_name" {
  type        = string
  description = "Source S3 bucket name for openid configuration files"
}

variable "src_bucket_path" {
  type        = string
  description = "Source S3 bucket path for openid configuration files (Must end with / if used)"
  default     = ""
}

variable "dest_bucket_name" {
  type        = string
  description = "Destination S3 bucket name for JWKS files"
}

variable "dest_bucket_path" {
  type        = string
  description = "Destination S3 bucket path for JWKS files (Must end with / if used)"
  default     = ""
}

variable "schedule_expression" {
  type        = string
  description = "Schedule expression of crawler. (See https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html)"
  default     = "rate(1 hour)"
}

variable "timeout" {
  type        = number
  description = "Timeout in seconds of of crawler/lambda functions."
  default     = 10
}
