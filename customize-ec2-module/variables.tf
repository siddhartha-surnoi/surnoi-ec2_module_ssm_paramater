variable "key_pair_name" {
  description = "Name of the key pair to use for EC2 instances"
  type        = string
  default     = "logistics-mot-kp"
}

# ---------------------------
# Common Tags
# ---------------------------
variable "security_group_tag" {
  description = "Common tags for all security groups"
  type        = map(string)
  default = {
    Project   = "logistics"
    ManagedBy = "Terraform"
    Owner     = "DevOpsTeam"
  }
}

variable "ec2_tags" {
  description = "Common EC2 instance tags"
  type        = map(string)
  default = {
    Project   = "logistics"
    ManagedBy = "Terraform"
    Owner     = "DevOpsTeam"
  }
}

# ---------------------------
# Security Groups
# ---------------------------
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
    jenkins_securitygroup = {
      name        = "jenkins-securitygroup"
      description = "Allow SSH and Jenkins ports"
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

    java_securitygroup = {
      name        = "backend-securitygroup"
      description = "Allow SSH and backend port 8080"
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

     }
}

# ---------------------------
# EC2 Instances
# ---------------------------
variable "instances" {
  description = "Map of EC2 instance configurations"
  type = map(object({
    instance_type        = string
    iam_instance_profile = string
    user_data            = string
    security_group_ref   = string
  }))

  default = {
    jenkins-master = {
      instance_type         = "t3a.small"
      iam_instance_profile  = "IAM-ECR-Role"
      user_data             = "user_data/user_data.jenkins.sh"
      security_group_ref    = "jenkins_securitygroup"
    }

    java-agent-1 = {
      instance_type         = "t3a.small"
      iam_instance_profile  = null
      user_data             = "user_data/user_data.backend.sh"
      security_group_ref    = "java_securitygroup"
    }



   
  }
}
