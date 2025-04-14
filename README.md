# terraform-random-pet

`terraform-random-pet` is a Terraform module that generates random, memorable pet names using the `random_pet` provider.
This module can be used to create unique, human-readable identifiers for cloud resources or other items where a
deterministic yet unique name is required.

## Features

- Generates random names with customizable word count.
- Ensures unique naming for resources.

## Usage

```hcl
module "example_random_pet" {
  source     = "./src/module"
  prefix     = "example"
  separator  = "-"
  word_count = 3
}

output "random_pet_name" {
  value = module.example_random_pet.name
}
```

## Contributing

Contributions are welcome! Please submit issues or pull requests to improve the module.

## License

See the `LICENSE` file for details.
