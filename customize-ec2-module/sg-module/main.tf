resource "aws_security_group" "this" {
  name        = var.security_group.name
  description = var.security_group.description
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.security_group_ingress
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = var.security_group_egress
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = var.security_group.tags
}
