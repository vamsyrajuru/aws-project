## Defining the S3 backend for the state file locking

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
  backend "s3" {
    bucket         	   = "rajuru-terraform-state-file-backend"
    key                = "state/terraform.tfstate"
    region         	   = "us-east-1"
    encrypt        	   = true
    use_lockfile       = true
  }
}