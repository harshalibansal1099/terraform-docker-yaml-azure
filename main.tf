data "azurerm_resource_group" "example" {
  name = var.resource_group_name
}

# 1. वर्चुअल नेटवर्क (VNet)
resource "azurerm_virtual_network" "main" {
  name                = "nodeapp-network"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = data.azurerm_resource_group.example.name
}

# 2. सबネット (Subnet)
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# 3. पब्लिक आईपी (Public IP) - Standard Static SKU
resource "azurerm_public_ip" "pip" {
  name                = "nodeapp-public-ip"
  resource_group_name = data.azurerm_resource_group.example.name
  location            = var.location
  allocation_method   = "Static"   # Standard SKU के लिए Static होना ज़रूरी है
  sku                 = "Standard" 
  sku_tier            = "Regional"
}

# 4. नेटवर्क सिक्योरिटी ग्रुप (NSG) - फायरवॉल रूल्स
resource "azurerm_network_security_group" "nsg" {
  name                = "nodeapp-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.example.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22" # बदलाव: 3000 की जगह 80 किया
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP-WebPort"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 5. नेटवर्क इंटरफेस कार्ड (NIC) - Standard Static Support के साथ
resource "azurerm_network_interface" "nic" {
  name                = "nodeapp-nic"
  resource_group_name = data.azurerm_resource_group.example.name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"      # 👈 पब्लिक आईपी के साथ मैच करने के लिए इसे Static किया
    private_ip_address            = "10.0.2.10"    # 👈 एक फिक्स प्राइवेट आईपी दे दिया
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# 6. NIC और NSG को आपस में जोड़ना
resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 7. वर्चुअल मशीन (VM)
resource "azurerm_linux_virtual_machine" "main" {
  name                            = "nodeapp-vm"
  resource_group_name             = data.azurerm_resource_group.example.name
  location                        = var.location
  size                            = "Standard_D2s_v5"
  admin_username                  = "azureuser"
  admin_password                  = "CloudProject@2026"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}