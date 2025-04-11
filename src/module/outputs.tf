output "this" {
  value = var.random_pet == null ? random_pet.this[0].id : var.random_pet
}
