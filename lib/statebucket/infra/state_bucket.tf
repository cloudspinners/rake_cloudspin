module "state_bucket" {
  source = "infrablocks/encrypted-bucket/aws"
  version = "~> 0.1.12"

  bucket_name = "${var.state_bucket_name}"

  tags = {
    Component = "${var.component}"
  }
}
