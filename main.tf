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

# 2. सबनेट (Subnet)
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# 3. पब्लिक आईपी (Public IP)
resource "azurerm_public_ip" "pip" {
  name                = "nodeapp-public-ip"
  resource_group_name = data.azurerm_resource_group.example.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard" 
  sku_tier            = "Regional"
}

# 4. नेटवर्क收藏िटी ग्रुप (NSG) - यहाँ पोर्ट 3000 खुद खुल जाएगा!
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
    destination_port_range     = "22"
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

  # ✅ फिक्स 1: पोर्ट 3000 के लिए ऑटोमैटिक दरवाजा बना दिया
  security_rule {
    name                       = "NodeApp-Port"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 5. नेटवर्क इंटरफेस कार्ड (NIC)
resource "azurerm_network_interface" "nic" {
  name                = "nodeapp-nic"
  resource_group_name = data.azurerm_resource_group.example.name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"      
    private_ip_address            = "10.0.2.10"    
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# 6. NIC और NSG को आपस में जोड़ना
resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 7. वर्चुअल मशीन (VM) + डॉकर ऑटोमेशन स्क्रिप्ट 🐳
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

  # ✅ फिक्स 2: यह जादुई स्क्रिप्ट मशीन ऑन होते ही डॉकर इंस्टॉल करेगी और ऐप चला देगी!
  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y docker.io
              sudo systemctl start docker
              sudo systemctl enable docker
              
              # गिटहब से तुम्हारा डॉकर इमेज या पब्लिक इमेज पुल करके चलाना
              # अभी टेस्टिंग के लिए हम एक स्टैंडर्ड Node.js/Nginx कंटेनर पोर्ट 3000 पर लाइव कर रहे हैं
              sudo docker run -d -p 3000:80 --name my-web-app nginx
              EOF
  )
}