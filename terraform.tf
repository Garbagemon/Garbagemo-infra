terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "perma-terraform-state-bucket"
    dynamodb_table = "state-lock-garbagemon"
    key            = "garbagemon/TF/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    profile        = "personal-general"
  }
}
