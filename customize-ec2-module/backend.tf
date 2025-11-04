# terraform {
#   backend "s3" {
#     bucket         = "fusion-terraform-state-bucket1"
#     key            = "ec2/terraform.tfstate"
#     region         = "ap-south-1"
#     dynamodb_table = "fusion-terraform-lock"
#     encrypt        = true
#   }
# }
