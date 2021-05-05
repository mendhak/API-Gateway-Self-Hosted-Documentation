terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
   region = "eu-west-1"
}

resource "aws_lambda_function" "example" {
   function_name = "ServerlessExample"

   filename = "example.zip"

   handler = "main.handler"
   runtime = "nodejs10.x"

   role = aws_iam_role.lambda_exec.arn
}

resource "aws_iam_role" "lambda_exec" {
   name = "serverless_example_lambda"

   assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "example_basic_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}



resource "aws_api_gateway_rest_api" "example" {
  name        = "ServerlessExample"
  description = "Terraform Serverless Application Example"
}

resource "aws_api_gateway_resource" "docs" {
    rest_api_id = aws_api_gateway_rest_api.example.id
    parent_id   = aws_api_gateway_rest_api.example.root_resource_id
    path_part   = "docs"
}

resource "aws_api_gateway_method" "docs_root" {
   rest_api_id   = aws_api_gateway_rest_api.example.id
   resource_id   = aws_api_gateway_resource.docs.id
   http_method   = "ANY"
   authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_docs_root" {
   rest_api_id = aws_api_gateway_rest_api.example.id
   resource_id = aws_api_gateway_method.docs_root.resource_id
   http_method = aws_api_gateway_method.docs_root.http_method

   integration_http_method = "POST"
   type                    = "AWS_PROXY"
   uri                     = aws_lambda_function.example.invoke_arn
}

resource "aws_api_gateway_resource" "proxy" {
   rest_api_id = aws_api_gateway_rest_api.example.id
   parent_id   = aws_api_gateway_resource.docs.id
   path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
   rest_api_id   = aws_api_gateway_rest_api.example.id
   resource_id   = aws_api_gateway_resource.proxy.id
   http_method   = "ANY"
   authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
   rest_api_id = aws_api_gateway_rest_api.example.id
   resource_id = aws_api_gateway_method.proxy.resource_id
   http_method = aws_api_gateway_method.proxy.http_method

   integration_http_method = "POST"
   type                    = "AWS_PROXY"
   uri                     = aws_lambda_function.example.invoke_arn
}

resource "aws_api_gateway_method" "proxy_root" {
   rest_api_id   = aws_api_gateway_rest_api.example.id
   resource_id   = aws_api_gateway_rest_api.example.root_resource_id
   http_method   = "ANY"
   authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
   rest_api_id = aws_api_gateway_rest_api.example.id
   resource_id = aws_api_gateway_method.proxy_root.resource_id
   http_method = aws_api_gateway_method.proxy_root.http_method

   integration_http_method = "POST"
   type                    = "MOCK"
   uri                     = aws_lambda_function.example.invoke_arn

   lifecycle {
     ignore_changes = all
   }
}


resource "aws_api_gateway_deployment" "example" {
   depends_on = [
     aws_api_gateway_integration.lambda,
     aws_api_gateway_integration.lambda_root,
   ]


   rest_api_id = aws_api_gateway_rest_api.example.id
   stage_name  = "test"
}

resource "aws_lambda_permission" "apigw" {
   statement_id  = "AllowAPIGatewayInvoke"
   action        = "lambda:InvokeFunction"
   function_name = aws_lambda_function.example.function_name
   principal     = "apigateway.amazonaws.com"

   # The "/*/*" portion grants access from any method on any resource
   # within the API Gateway REST API.
   source_arn = "${aws_api_gateway_rest_api.example.execution_arn}/*/*"
}

output "go_to" {
   value = join("", [aws_api_gateway_deployment.example.invoke_url , "/docs/"])
}