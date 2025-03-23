## Defining the S3 backend for the state file locking

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
  backend "s3" {
    bucket         	   = "vamsy-rajuru-terraform-state-file-backend"
    key                = "state/terraform.tfstate"
    region         	   = "us-west-2"
    encrypt        	   = true
    dynamodb_table     = "challenge_tf_lock"
  }
}