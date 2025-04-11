variable "random_pet" {
  description = <<EOF
  A string that, if set to null, will trigger the creation of a random pet resource.
If set to any non-null value, the resource will not be created.
  EOF
  type        = string
  default     = null
}

variable "length" {
  description = <<EOF
  The length of the random pet name to generate.
Defaults to 3.
EOF
  type        = number
  default     = 3
}
