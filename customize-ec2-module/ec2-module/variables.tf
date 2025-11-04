variable "ami_id" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "security_group_id" {}
variable "key_pair_name" {}
variable "user_data" {}
variable "tags" { type = map(string) }
variable "instance_name" {}
# Optional IAM Role
variable "iam_instance_profile" {
  description = "IAM instance profile name or ARN (optional)"
  type        = string
  default     = ""
}