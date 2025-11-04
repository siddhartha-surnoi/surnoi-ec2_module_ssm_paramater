resource "aws_key_pair" "key_pair" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.rsa-4096-example.public_key_openssh
}

resource "tls_private_key" "rsa-4096-example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content  = tls_private_key.rsa-4096-example.private_key_pem
  filename = var.key_pair_name
}