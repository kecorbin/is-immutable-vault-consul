resource "aws_s3_bucket" "consul_data" {
  bucket = "${var.name_prefix}-consul-data"
  acl    = "private"
}