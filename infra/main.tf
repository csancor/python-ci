terraform {
  backend "s3" {
    bucket = "sample-bucket-555" # Nome do bucket no S3
    key    = "terraform.tfstate" # Caminho para o arquivo de estado dentro do bucket
    region = "us-east-1"         # Região do bucket S3


  }
}


terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0" # Altere para a versão que você está utilizando
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}


provider "aws" {
  region = "us-east-1" # Defina a região desejada
}

resource "aws_lambda_function" "hello_world_function" {
  function_name = "hello_world_function"
  package_type  = "Image"
  architectures = ["x86_64"]
  image_uri     = "${aws_ecr_repository.hello_world_repository.repository_url}:python3.11-v1"
  role          = aws_iam_role.hello_world_function_role.arn

  environment {
    variables = {
      ENV_VAR_NAME = "value" # Adicione suas variáveis de ambiente aqui, se necessário
    }
  }

  timeout = 3
}

resource "aws_iam_role" "hello_world_function_role" {
  name = "hello_world_function_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "hello_world_function_policy" {
  role = aws_iam_role.hello_world_function_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = "ecr:*"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_api_gateway_rest_api" "hello_world_api" {
  name        = "HelloWorldApi"
  description = "API Gateway for Hello World Lambda function"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "hello_world_resource" {
  rest_api_id = aws_api_gateway_rest_api.hello_world_api.id
  parent_id   = aws_api_gateway_rest_api.hello_world_api.root_resource_id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "hello_world_method" {
  rest_api_id   = aws_api_gateway_rest_api.hello_world_api.id
  resource_id   = aws_api_gateway_resource.hello_world_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "hello_world_integration" {
  rest_api_id             = aws_api_gateway_rest_api.hello_world_api.id
  resource_id             = aws_api_gateway_resource.hello_world_resource.id
  http_method             = aws_api_gateway_method.hello_world_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello_world_function.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.hello_world_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "hello_world_deployment" {
  depends_on  = [aws_api_gateway_integration.hello_world_integration]
  rest_api_id = aws_api_gateway_rest_api.hello_world_api.id
  stage_name  = "prod"
}

resource "aws_ecr_repository" "hello_world_repository" {
  name = "hello_world_repository"
}

output "hello_world_api_url" {
  description = "API Gateway endpoint URL for Hello World function"
  value       = "https://${aws_api_gateway_rest_api.hello_world_api.id}.execute-api.${var.aws_region}.amazonaws.com/prod/hello/"
}

output "hello_world_lambda_arn" {
  description = "Hello World Lambda Function ARN"
  value       = aws_lambda_function.hello_world_function.arn
}

output "hello_world_function_role_arn" {
  description = "IAM Role ARN for Hello World Lambda Function"
  value       = aws_iam_role.hello_world_function_role.arn
}
