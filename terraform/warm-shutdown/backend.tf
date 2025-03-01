terraform {
  backend "s3" {
    bucket         = "zero2prod-terraform-state"
    key            = "warm-shutdown/terraform.tfstate"
    region         = "eu-west-1"
    # encrypt        = true
    # dynamodb_table = "terraform-lock"
  }
}