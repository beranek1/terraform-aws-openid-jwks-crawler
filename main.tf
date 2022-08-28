terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

data "archive_file" "crawler" {
  type             = "zip"
  source_file      = "${path.module}/index.js"
  output_file_mode = "0666"
  output_path      = "${path.module}/crawler.zip"
}

data "aws_iam_policy_document" "crawler" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "crawler" {
  name               = "${var.prefix}role"
  assume_role_policy = data.aws_iam_policy_document.crawler.json
}

resource "aws_iam_policy" "crawler" {
  name = "${var.prefix}policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:PutObject"]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.dest_bucket_name}/${var.dest_bucket_path}*"
      },
      {
        Action   = ["s3:GetObject"]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.src_bucket_name}/${var.src_bucket_path}*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "crawler" {
  role       = aws_iam_role.crawler.name
  policy_arn = aws_iam_policy.crawler.arn
}

resource "aws_lambda_function" "crawler" {
  filename      = data.archive_file.crawler.output_path
  function_name = "${var.prefix}function"
  role          = aws_iam_role.crawler.arn
  handler       = "index.handler"

  source_code_hash = data.archive_file.crawler.output_base64sha256

  runtime = "nodejs16.x"

  environment {
    variables = {
      oidc_providers   = jsonencode(var.oidc_providers)
      src_bucket_name  = var.src_bucket_name
      src_bucket_path  = var.src_bucket_path
      dest_bucket_name = var.dest_bucket_name
      dest_bucket_path = var.dest_bucket_path
    }
  }
}

resource "aws_lambda_permission" "crawler" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.crawler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.crawler.arn
}

resource "aws_cloudwatch_event_rule" "crawler" {
  name                = "${var.prefix}rule"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "crawler" {
  rule = aws_cloudwatch_event_rule.crawler.name

  arn = aws_lambda_function.crawler.arn
}
