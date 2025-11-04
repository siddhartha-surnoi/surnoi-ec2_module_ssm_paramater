resource "aws_instance" "ec2_instance" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [var.security_group_id]
  user_data                   = var.user_data
  # Optional IAM Role
  iam_instance_profile = var.iam_instance_profile != "" ? var.iam_instance_profile : null
  tags = merge(
    var.tags,
    {
      Name = var.instance_name
    }
  )
}






