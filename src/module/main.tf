resource "random_pet" "this" {
  count = var.random_pet == null ? 1 : 0

  length = var.length
}
