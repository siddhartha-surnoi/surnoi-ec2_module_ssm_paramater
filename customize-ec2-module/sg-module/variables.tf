variable "vpc_id" {
  type = string
}

variable "security_group" {
  type = object({
    name        = string
    description = string
    tags        = map(string)
  })
}

variable "security_group_ingress" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

variable "security_group_egress" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}
