output "key_name" {
  value = var.key_pair_name
}

output "public_ips" {
  value = [for instance in module.ec2_instances : instance.public_ip]
}

output "private_ips" {
  value = [for instance in module.ec2_instances : instance.private_ip]
}



