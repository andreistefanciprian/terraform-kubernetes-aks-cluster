# Generate random suffix for unique resource group naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}