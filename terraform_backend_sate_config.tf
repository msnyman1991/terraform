terraform {
 backend "s3" {
 encrypt = true
 bucket = "<bucket_name>"
 region = "eu-west-1"
 key = "terraform_state"
 access_key = ""
 secret_key = ""
 }
}