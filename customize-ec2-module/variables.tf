#########################################
# EC2 INSTANCES
#########################################
variable "instances" {
  description = "Map of EC2 instance configurations"
  type = map(object({
    instance_type        = string
    iam_instance_profile = optional(string)
    user_data            = string
    security_group_ref   = string
    label                = optional(string)
  }))
 
  default = {
    jenkins-master = {
      instance_type        = "t3a.small"
      iam_instance_profile = "IAM-ECR-Role"
      user_data            = "user_data/user_data.jenkins.sh"
      security_group_ref   = "jenkins_securitygroup"
      label                = "master"
    }
 
    java-agent-1 = {
      instance_type        = "t3a.micro"
      iam_instance_profile = "IAM-ECR-Role"
      user_data            = "user_data/user_data.java.sh"
      security_group_ref   = "java_securitygroup"
      label                = "java"
    }
 
    java-agent-2 = {
      instance_type        = "t3a.micro"
      iam_instance_profile = "IAM-ECR-Role"
      user_data            = "user_data/user_data.java.sh"
      security_group_ref   = "java_securitygroup"
      label                = "java"
    }
 
    java-agent-3 = {
      instance_type        = "t3a.micro"
      iam_instance_profile = "IAM-ECR-Role"
      user_data            = "user_data/user_data.java.sh"
      security_group_ref   = "java_securitygroup"
      label                = "java"
    }
 
    ml-agent-1 = {
      instance_type        = "t3a.medium"
      iam_instance_profile = "IAM-ECR-Role"
      user_data            = "user_data/user_data.ml.sh"
      security_group_ref   = "ml_securitygroup"
      label                = "ml"
    }
  }
}
 
#########################################
# TAGS
#########################################
variable "ec2_tags" {
  description = "Common EC2 instance tags"
  type        = map(string)
  default = {
    Project   = "logistics"
    ManagedBy = "Terraform"
    Owner     = "DevOpsTeam"
  }
}
 
variable "security_group_tag" {
  description = "Common tags for all security groups"
  type        = map(string)
  default = {
    Project   = "logistics"
    ManagedBy = "Terraform"
    Owner     = "DevOpsTeam"
  }
}
 
#########################################
# ENVIRONMENT & NETWORK SETTINGS
#########################################
variable "environment" {
  description = "Deployment environment (dev/stage/prod)"
  type        = string
  default     = "dev"
}
 
variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
  default     = "vpc-0086f34dccaccfc5c"
}
 
variable "key_pair_name" {
  description = "Name of the key pair to use for EC2 instances"
  type        = string
  default     = "logistics-mot-kp"
}
 
#########################################
# SECURITY GROUPS
#########################################
variable "security_groups" {
  description = "Map of security group configurations"
  type = map(object({
    name        = string
    description = string
    ingress     = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    }))
    egress = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    }))
  }))
 
  default = {
    #########################################
    # Jenkins Master SG (22, 8080)
    #########################################
    jenkins_securitygroup = {
      name        = "jenkins-securitygroup"
      description = "Allow SSH and Jenkins web access"
      ingress = [
        {
          from_port   = 22
          to_port     = 22
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        },
        {
          from_port   = 8080
          to_port     = 8080
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
      egress = [
        {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
    }
 
    #########################################
    # Java Agent SG (22, 8080)
    #########################################
    java_securitygroup = {
      name        = "java-securitygroup"
      description = "Allow SSH and backend communication for Java agents"
      ingress = [
        {
          from_port   = 22
          to_port     = 22
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        },
        {
          from_port   = 8080
          to_port     = 8080
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
      egress = [
        {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
    }
 
    #########################################
    # ML Agent SG (22, 8000)
    #########################################
    ml_securitygroup = {
      name        = "ml-securitygroup"
      description = "Allow SSH and ML service port access"
      ingress = [
        {
          from_port   = 22
          to_port     = 22
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        },
        {
          from_port   = 8000
          to_port     = 8000
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
      egress = [
        {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      ]
    }
  }
}
