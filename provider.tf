terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0" 
    }
  }
}

provider "azurerm" {
  features {} # इसे खाली छोड़ना जरूरी है, यह Azure की सेटिंग्स को एक्टिवेट करता है
}