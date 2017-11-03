# Create an Azure resource group
resource "azurerm_resource_group" "terraform" {
  name     = "TerraformDemo-RG"
  location = "${var.location}" # Default Azure location as defined in variables.tf
}

# Create a virtual network in the Terraform resource group
resource "azurerm_virtual_network" "terraform" {
  name                = "Terraform-VNet"
  address_space       = ["172.16.0.0/16"]
  resource_group_name = "${azurerm_resource_group.terraform.name}"
  location = "${var.location}" 
}

# Create a subnet in Terraform VNet
resource "azurerm_subnet" "terraform" {
  name                 = "Subnet-01"
  resource_group_name  = "${azurerm_resource_group.terraform.name}"
  virtual_network_name = "${azurerm_virtual_network.terraform.name}"
  address_prefix       = "172.16.1.0/24"
}

# Create a public IP resource
resource "azurerm_public_ip" "terraform" {
  name                         = "Terraform-01-Public-IP"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.terraform.name}"
  public_ip_address_allocation = "dynamic"
} 

# Create a network secuirty group with some rules
resource "azurerm_network_security_group" "terraform" {
  name                = "Terraform-NSG"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.terraform.name}"

  security_rule {
    name                       = "allow_SSH"
    description                = "Allow SSH access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

    security_rule {
    name                       = "allow_RDP"
    description                = "Allow Remote Desktop access"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}  

# Create a network interface
    # Attach the previously created public IP
    # Attach the previously created NSG
resource "azurerm_network_interface" "terraform" {
  name                = "Terraform-NIC"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.terraform.name}"
  network_security_group_id     = "${azurerm_network_security_group.terraform.id}"
  
  ip_configuration {
    name                          = "terraformconfiguration"
    subnet_id                     = "${azurerm_subnet.terraform.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.terraform.id}"  
 }
}

# Create a new managed disk
resource "azurerm_managed_disk" "terraform" {
  name = "Terraform-Data-02"
  location = "${var.location}"
  resource_group_name = "${azurerm_resource_group.terraform.name}"
  storage_account_type = "Standard_LRS"
  create_option = "Empty"
  disk_size_gb = "20"
}  

# Create a new virtual machine 
resource "azurerm_virtual_machine" "terraform" {
  name                  = "Terraform-01"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.terraform.name}"
  network_interface_ids = ["${azurerm_network_interface.terraform.id}"]
  vm_size               = "Standard_D2_v3"
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "14.04.2-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "Terraform-OS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  # Create a new data disk (unmanged)
  storage_data_disk {
    name              = "Terraform-Data-01"
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    lun               = 0
    disk_size_gb      = "50"
  }

  # Attach the previously created data disk (managed)
  storage_data_disk {
    name            = "${azurerm_managed_disk.terraform.name}"
    managed_disk_id = "${azurerm_managed_disk.terraform.id}"
    create_option   = "Attach"
    lun             = 1
    disk_size_gb    = "${azurerm_managed_disk.terraform.disk_size_gb}"
  }

  # Set hostname, username & password
  os_profile {
    computer_name  = "terraform-01"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

}