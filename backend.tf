#state.tf
terraform { 
    backend "s3" {
      bucket         = "terraform-state-guinho-virginia"
      key            = "kunlatek/terraform.tfstate"
      region         = "us-east-1"
      encrypt        = true
      use_lockfile   = true
    }
}

