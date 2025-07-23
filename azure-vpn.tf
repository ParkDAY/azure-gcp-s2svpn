provider "azurerm" {
  features { }
  subscription_id = "3bfbdffb-7f3a-4c15-9876-1566068161cb"
}

resource "azurerm_resource_group" "vpn-test" {
  name = "vpn-test"
  location = "Korea Central"
}

resource "azurerm_virtual_network" "vpn-vn-network" {
  name = "vpn-test-network"
  resource_group_name = azurerm_resource_group.vpn-test.name
  location = azurerm_resource_group.vpn-test.location
  address_space = [ "20.0.0.0/16" ]
}

resource "azurerm_subnet" "vpn-subnet" {
  name = "pubB-sn"
  resource_group_name = azurerm_resource_group.vpn-test.name
  virtual_network_name = azurerm_virtual_network.vpn-vn-network.name
  address_prefixes = [ "20.0.1.0/24" ]
}

resource "azurerm_subnet" "gateway-subnet" {
  name = "GatewaySubnet"
  resource_group_name = azurerm_resource_group.vpn-test.name
  virtual_network_name = azurerm_virtual_network.vpn-vn-network.name
  address_prefixes = [ "20.0.2.0/24" ]
}

# resource "azurerm_subnet" "bastion-subnet" {
#   name = "bastionsubnet"
#   resource_group_name = azurerm_resource_group.vpn-test.name
#   virtual_network_name = azurerm_virtual_network.vpn-vn-network.name
#   address_prefixes = [ "20.0.3.0/26" ]
# }

resource "azurerm_public_ip" "vpn-public-ip1" {
  name = "vpn-public-ip1"
  location = azurerm_resource_group.vpn-test.location
  resource_group_name = azurerm_resource_group.vpn-test.name
  allocation_method = "Static"
  sku = "Standard"
}

resource "azurerm_public_ip" "vpn-public-ip2" {
  name = "vpn-public-ip2"
  location = azurerm_resource_group.vpn-test.location
  resource_group_name = azurerm_resource_group.vpn-test.name
  allocation_method = "Static"
  sku = "Standard"
}

resource "azurerm_virtual_network_gateway" "vgwB" {
  name = "vgwB"
  location = azurerm_resource_group.vpn-test.location
  resource_group_name = azurerm_resource_group.vpn-test.name
  type = "Vpn"
  sku = "VpnGw2"
  active_active = true
  enable_bgp = true
  ip_configuration {
    name = "vpn1"
    subnet_id = azurerm_subnet.gateway-subnet.id
    public_ip_address_id = azurerm_public_ip.vpn-public-ip1.id
  }
  ip_configuration {
    name = "vpn2"
    subnet_id = azurerm_subnet.gateway-subnet.id
    public_ip_address_id = azurerm_public_ip.vpn-public-ip2.id
  }
  bgp_settings {
    asn = 65515
    peering_addresses{
      ip_configuration_name = "vpn1"
      apipa_addresses = ["169.254.21.1"]
    }
    peering_addresses{
      ip_configuration_name = "vpn2"
      apipa_addresses = ["169.254.22.1"]
    }
  }
}

resource "azurerm_local_network_gateway" "lgwB1" {
  name = "lgwB1"
  location = azurerm_resource_group.vpn-test.location
  resource_group_name = azurerm_resource_group.vpn-test.name
  gateway_address = google_compute_ha_vpn_gateway.ha-gateway.vpn_interfaces[0].ip_address
  bgp_settings {
    asn = 65000
    bgp_peering_address = google_compute_router_peer.route-peer1.ip_address
  }
}

resource "azurerm_local_network_gateway" "lgwB2" {
  name = "lgwB2"
  location = azurerm_resource_group.vpn-test.location
  resource_group_name = azurerm_resource_group.vpn-test.name
  gateway_address = google_compute_ha_vpn_gateway.ha-gateway.vpn_interfaces[1].ip_address
  bgp_settings {
    asn = 65000
    bgp_peering_address = google_compute_router_peer.route-peer2.ip_address
  }
}

resource "azurerm_virtual_network_gateway_connection" "vpnB1" {
  name = "azrm-aws-vpn-connection1"
  location = azurerm_resource_group.vpn-test.location
  resource_group_name = azurerm_resource_group.vpn-test.name
  type = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vgwB.id
  local_network_gateway_id = azurerm_local_network_gateway.lgwB1.id
  shared_key = "test123456"
  enable_bgp = true
}

resource "azurerm_virtual_network_gateway_connection" "vpnB2" {
  name = "azrm-aws-vpn-connection2"
  location = azurerm_resource_group.vpn-test.location
  resource_group_name = azurerm_resource_group.vpn-test.name
  type = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vgwB.id
  local_network_gateway_id = azurerm_local_network_gateway.lgwB2.id
  shared_key = "test123456"
  enable_bgp = true
}

resource "azurerm_network_interface" "vpn-network-interface" {
  name = "vpn-network-interface-testing"
  location = azurerm_resource_group.vpn-test.location
  resource_group_name = azurerm_resource_group.vpn-test.name
  ip_configuration {
    name = "vpn-ip-configuration"
    subnet_id = azurerm_subnet.vpn-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.vpn-public-ip.id
  }
}

resource "azurerm_public_ip" "vpn-public-ip" {
  name = "vpn-public-ip"
  location = azurerm_resource_group.vpn-test.location
  resource_group_name = azurerm_resource_group.vpn-test.name
  allocation_method = "Static"
  sku = "Standard"
}

resource "azurerm_virtual_machine" "testing-vm" {
  name = "testing_vm"
  location = azurerm_resource_group.vpn-test.location
  resource_group_name = azurerm_resource_group.vpn-test.name
  network_interface_ids = [ azurerm_network_interface.vpn-network-interface.id ]
  vm_size = "Standard_B1s"
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true
  storage_image_reference {
    publisher = "Canonical"
    offer = "0001-com-ubuntu-server-jammy"
    sku = "22_04-lts"
    version = "latest"
  }
  storage_os_disk {
    name = "vpn-storage-os-disk"
    create_option = "FromImage"
    
  }
  os_profile {
    computer_name = "hostname"
    admin_username = "terraform"
    admin_password = "Terraform1220."
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}

# resource "azurerm_bastion_host" "vpn-bastion" {
#   name = "vpn_bastion"
#   location = azurerm_resource_group.vpn-test.location
#   resource_group_name = azurerm_resource_group.vpn-test.name
#   ip_configuration {
#     name = "config"
#     subnet_id = azurerm_subnet.bastion-subnet.id
#     public_ip_address_id = azurerm_public_ip.vpn-public-ip.id
#   }
# }
