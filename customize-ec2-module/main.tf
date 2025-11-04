##################################
# SECURITY GROUP MODULE
##################################
module "security_groups" {
  source   = "./sg-module"
  for_each = var.security_groups

  vpc_id = local.vpc_id

  security_group = {
    name        = each.value.name
    description = each.value.description
    tags        = var.security_group_tag
  }

  security_group_ingress = each.value.ingress
  security_group_egress  = each.value.egress
}

##################################
# EC2 MODULE
##################################
module "ec2_instances" {
  source   = "./ec2-module"
  for_each = var.instances

  ami_id            = data.aws_ami.ubuntu.id
  subnet_id         = local.public_subnet_id
  instance_type     = each.value.instance_type
  key_pair_name     = var.key_pair_name
  security_group_id = module.security_groups[each.value.security_group_ref].security_group_id
  user_data         = file(each.value.user_data)
  tags              = var.ec2_tags
  instance_name     = each.key
  iam_instance_profile = each.value.iam_instance_profile
}
