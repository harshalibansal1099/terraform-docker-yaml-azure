terraform {
  backend "azurerm" {
    resource_group_name  = "free-resources-rg"
    storage_account_name = "harshfreestate2026" # यहाँ अपना यूनिक नाम लिखो
    container_name       = "free-tfstate"
    key                  = "free.terraform.tfstate"
  }
}