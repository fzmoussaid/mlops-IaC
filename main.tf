terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_s3_bucket" "model-metadata-test" {
  bucket = "model-metadata-test"

  tags = {
    Name        = "model-metadata-test"
    Environment = "Dev"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "src/inference_lambda.py"
  output_path = "inference_lambda.zip"
}

resource "aws_lambda_function" "inference_lambda" {
  filename      = "inference_lambda.zip"
  function_name = "inference_lambda"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "inference_lambda.handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.9"

  environment {
    variables = {
      TEST_ENV_VAR = "Test"
    }
  }
}


# ## Inference endpoint
# resource "aws_sagemaker_endpoint" "inference_endpoint" {
#   name                 = "inference-endpoint"
#   endpoint_config_name = aws_sagemaker_endpoint_configuration.inference_endpoint_config.name

#   tags = {
#     Name = "dev-endpoint"
#   }
# }

# resource "aws_sagemaker_endpoint_configuration" "inference_endpoint_config" {
#   name = "inference-endpoint-config"

#   production_variants {
#     variant_name           = "DevVariant"
#     model_name             = "kmeansTestModel"

#     serverless_config {
#       max_concurrency = 10
#       memory_size_in_mb = 3072
#     }
#   }

#   tags = {
#     Name = "dev-endpoint-config"
#   }
# }

# todo: add model
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sagemaker_model

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/sagemaker_prebuilt_ecr_image


## Sagemaker Model
resource "aws_sagemaker_model" "kmeansTestModel" {
  name               = "kmeansTestModel"
  execution_role_arn = aws_iam_role.modelIamRole.arn

  primary_container {
    image = data.aws_sagemaker_prebuilt_ecr_image.kmeansEcrImage.registry_path
  }
}

resource "aws_iam_role" "modelIamRole" {
  assume_role_policy = data.aws_iam_policy_document.sagemaker_assume_role.json
}

data "aws_iam_policy_document" "sagemaker_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
}

data "aws_sagemaker_prebuilt_ecr_image" "kmeansEcrImage" {
  repository_name = "kmeans"
}