variable "account_id" { type = string }
variable "discord_bot_public_key" { type = string }

data "aws_iam_policy_document" "awc_wideo_bot_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "awc_wideo_bot" {
  name               = "awc_wideo_bot"
  assume_role_policy = data.aws_iam_policy_document.awc_wideo_bot_assume.json
}

data "aws_iam_policy_document" "awc_wideo_bot_permissions" {
  statement {
    actions = [
      # for logging from the lambda itself
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
}
resource "aws_iam_role_policy" "awc_wideo_bot" {
  role   = aws_iam_role.awc_wideo_bot.name
  policy = data.aws_iam_policy_document.awc_wideo_bot_permissions.json
}

resource "aws_lambda_function" "awc_wideo_bot" {
  function_name = "awc_wideo_bot"
  filename      = "${path.module}/data/placeholder_lambda.zip"
  role          = aws_iam_role.awc_wideo_bot.arn
  handler       = "bootstrap"
  runtime       = "provided.al2"
  timeout       = 5

  environment {
    variables = {
      BOT_PUBLIC_KEY = var.discord_bot_public_key
    }
  }
}

resource "aws_cloudwatch_log_group" "awc_wideo_bot" {
  name              = "/aws/lambda/awc_wideo_bot"
  retention_in_days = 90
}

resource "aws_apigatewayv2_api" "awc_wideo_bot" {
  name          = "awc_wideo_bot"
  protocol_type = "HTTP"
  target        = aws_lambda_function.awc_wideo_bot.arn
}

resource "aws_lambda_permission" "awc_wideo_bot" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.awc_wideo_bot.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.awc_wideo_bot.execution_arn}/*/*"
}

output "awc_wideo_bot_api" {
  value = aws_apigatewayv2_api.awc_wideo_bot.api_endpoint
}

data "aws_iam_policy_document" "awc_wideo_bot_deploy_assume" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:anthonywritescode/awcWideoBot:*"]
    }
  }
}
resource "aws_iam_role" "awc_wideo_bot_deploy" {
  name               = "awc_wideo_bot_deploy"
  assume_role_policy = data.aws_iam_policy_document.awc_wideo_bot_deploy_assume.json
}

data "aws_iam_policy_document" "awc_wideo_bot_deploy" {
  statement {
    actions = [
      "lambda:GetFunction",
      "lambda:UpdateFunctionCode",
    ]
    resources = [aws_lambda_function.awc_wideo_bot.arn]
  }
}
resource "aws_iam_role_policy" "awc_wideo_bot_deploy" {
  role   = aws_iam_role.awc_wideo_bot_deploy.id
  policy = data.aws_iam_policy_document.awc_wideo_bot_deploy.json
}

output "awc_wideo_bot_deploy_arn" {
  value = aws_iam_role.awc_wideo_bot_deploy.arn
}
