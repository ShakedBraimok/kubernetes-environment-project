terraform {
  backend "s3" {
    # Replace with your S3 bucket name for Terraform state
    bucket = "senora-terraform-state-kubernetes-environment-project-69214fc7307cdc8b159f63e9"

    # This is the path to the state file inside the bucket
    key = "kubernetes-environment-project/terraform.tfstate"

    # Replace with the AWS region of your bucket
    region = "eu-west-1"

    # Optional, but highly recommended for state locking to prevent conflicts
    # dynamodb_table = "your-terraform-lock-table-name"
  }
}
