# EC2 Infrastructure with Terraform

## Prerequisites
- Terraform installed ([Download Here](https://www.terraform.io/downloads))
- AWS CLI configured with appropriate credentials
- An existing AWS account

## Inputs

### EC2 Configuration
| Name          | Description                 | Type   | Example |
|--------------|-----------------------------|--------|---------|
| `ami`        | Amazon Machine Image ID     | string | `ami-12345678` |
| `instance_type` | EC2 instance type          | string | `t2.micro` |
| `tags`       | Tags for the EC2 instance   | map(string) | `{ Name = "MyEC2", Environment = "Dev" }` |

### Key Pair Configuration
| Name          | Description                 | Type   | Example |
|--------------|-----------------------------|--------|---------|
| `key_pair_name` | Name of the Key Pair       | string | `my-key-pair` |

### Security Group Configuration
| Name          | Description                 | Type   | Example |
|--------------|-----------------------------|--------|---------|
| `name`       | Security Group name         | string | `my-security-group` |
| `description` | Security Group description | string | `Allow traffic` |
| `ingress_rules` | Ingress rules (map) | map(object) | See below |
| `egress_rules` | Egress rules (map) | map(object) | See below |
| `tags`       | Tags for Security Group     | map(string) | `{ Name = "SG", Managed_By = "Terraform" }` |

**Note**: Security group consider default VPC
#### Example: Ingress Rules
```hcl
variable "security_group_ingress" {
  default = {
    key1 = {  # Required
        cidr_ipv4    = "0.0.0.0/0"
        from_port    = 22
        ip_protocol  = "tcp"
        to_port      = 22
    }
    key2 = {  # Optional
        cidr_ipv4    = "0.0.0.0/0"
        from_port    = 80
        ip_protocol  = "tcp"
        to_port      = 80
    }
    key3 = {  # Allow all traffic if required
        cidr_ipv4    = "0.0.0.0/0"
        ip_protocol  = "-1"
    }
  }
}
```

#### Example: Egress Rules
```hcl
variable "security_group_egress_config" {
  default = {
    egress_rule1 = {
        cidr_ipv4   = "0.0.0.0/0"
        ip_protocol = "-1"
    }
  }
}
```

## Outputs
| Name               | Description                        |
|--------------------|----------------------------------|
| `key_pair_name`    | Name of the created Key Pair    |
| `security_group_id` | ID of the created Security Group |
| `public_ip`        | Public IP of the EC2 instance    |

## Usage
1. Initialize Terraform:
   ```sh
   terraform init
   ```
2. Plan the deployment:
   ```sh
   terraform plan
   ```
   ```sh
    terraform plan
        var.key_pair_name
        key_pair_name

        Enter a value:
   ```
   **Note**: ``ENTER`` for By Default *.pem* will be created on EC2 instance name, for custom we can provide name ex: **sample.pem** , it will be saved current location. same for while ``terraform apply`` and ``terraform destroy``

3. Apply the changes:
   ```sh
   terraform apply -auto-approve
   ```
4. Destroy resources if needed:
   ```sh
   terraform destroy -auto-approve
   ```

