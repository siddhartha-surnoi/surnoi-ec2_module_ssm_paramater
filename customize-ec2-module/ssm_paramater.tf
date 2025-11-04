####################################################
# Networking Configuration (via SSM Parameters)
####################################################

# Fetch VPC ID from SSM Parameter Store
data "aws_ssm_parameter" "vpc_id" {
  name = "/logistics-mot/dev/vpc_id"
}

data "aws_ssm_parameter" "public_subnets" {
  name = "/logistics-mot/dev/public_subnets"
}

