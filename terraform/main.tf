locals {
  name = "${var.prefix}-guzfarma-${var.environment}"
}

# --- Usuarios (Cognito) ---
resource "aws_cognito_user_pool" "this" {
  name = "${local.name}-users"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "${local.name}-web"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret     = false
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]

  access_token_validity = 60
  id_token_validity     = 60
  token_validity_units {
    access_token = "minutes"
    id_token     = "minutes"
  }
}

resource "aws_cognito_user_group" "roles" {
  for_each     = toset(["administrador", "farmaceutico", "vendedor", "cliente"])
  name         = each.key
  user_pool_id = aws_cognito_user_pool.this.id
}

# --- Lambda "productos" ---
data "archive_file" "productos" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/productos"
  output_path = "${path.module}/.build/productos.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name = "${local.name}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_cloudwatch_log_group" "productos" {
  name              = "/aws/lambda/${local.name}-productos"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role_policy" "lambda_logs" {
  name = "logs"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.productos.arn}:*"
    }]
  })
}

resource "aws_lambda_function" "productos" {
  function_name    = "${local.name}-productos"
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.productos.output_path
  source_code_hash = data.archive_file.productos.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  depends_on = [aws_cloudwatch_log_group.productos, aws_iam_role_policy.lambda_logs]
}

# --- API Gateway HTTP con authorizer JWT de Cognito ---
resource "aws_apigatewayv2_api" "this" {
  name          = "${local.name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "productos" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.productos.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.this.id
  name             = "cognito"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.this.id}"
    audience = [aws_cognito_user_pool_client.web.id]
  }
}

# Ruta pública para comprobar que la API responde.
resource "aws_apigatewayv2_route" "salud" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /salud"
  target    = "integrations/${aws_apigatewayv2_integration.productos.id}"
}

# Ruta protegida: sin token de Cognito responde 401.
resource "aws_apigatewayv2_route" "productos" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "GET /productos"
  target             = "integrations/${aws_apigatewayv2_integration.productos.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = 10
    throttling_burst_limit = 20
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.productos.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
