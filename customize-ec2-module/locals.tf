# Parse the first subnet from the list
locals {
  vpc_id            = data.aws_ssm_parameter.vpc_id.value
  public_subnet_ids = split(",", data.aws_ssm_parameter.public_subnets.value)
  public_subnet_id  = local.public_subnet_ids[0] # pick first subnet
}