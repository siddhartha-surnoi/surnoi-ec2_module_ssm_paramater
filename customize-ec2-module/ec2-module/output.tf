output "instance_id" {
  value = aws_instance.ec2_instance.id
}

output "private_ip" {
  value = aws_instance.ec2_instance.private_ip
}

output "public_ip" {
  value = aws_instance.ec2_instance.public_ip
}

output "instance_name" {
  value = aws_instance.ec2_instance.tags["Name"]
}
