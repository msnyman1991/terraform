/*resource "aws_s3_bucket" "terraform-state-storage-s3" {
    bucket = "<bucket_name>"
 
    versioning {
      enabled = true
    }
 
    lifecycle {
      prevent_destroy = true
    }      
}
*/