# Example only. Create the bucket and DynamoDB table first, or bootstrap them separately.
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "credpal/prod/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

