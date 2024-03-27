provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rsg" {
  name     = "database-rg"
  location = "West Europe"
}

resource "azurerm_network_security_group" "sqlnsg" {
  name                = "mi-security-group"
  location            = azurerm_resource_group.rsg.location
  resource_group_name = azurerm_resource_group.rsg.name
}


resource "azurerm_network_security_rule" "allow_management_inbound" {
  name                        = "allow_management_inbound"
  priority                    = 106
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["9000", "9003", "1438", "1440", "1452"]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.sqlnsg.name
}

resource "azurerm_network_security_rule" "allow_misubnet_inbound" {
  name                        = "allow_misubnet_inbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.0.0.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.sqlnsg.name
}

resource "azurerm_network_security_rule" "allow_health_probe_inbound" {
  name                        = "allow_health_probe_inbound"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.sqlnsg.name
}

resource "azurerm_network_security_rule" "allow_tds_inbound" {
  name                        = "allow_tds_inbound"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.sqlnsg.name
}

resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "deny_all_inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.sqlnsg.name
}

resource "azurerm_network_security_rule" "allow_management_outbound" {
  name                        = "allow_management_outbound"
  priority                    = 102
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443", "12000"]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.sqlnsg.name
}

resource "azurerm_network_security_rule" "allow_misubnet_outbound" {
  name                        = "allow_misubnet_outbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.0.0.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.sqlnsg.name
}

resource "azurerm_network_security_rule" "deny_all_outbound" {
  name                        = "deny_all_outbound"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.sqlnsg.name
}

resource "azurerm_virtual_network" "sqlvnet" {
  name                = "vnet-mi"
  resource_group_name = azurerm_resource_group.rsg.name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rsg.location
}

resource "azurerm_subnet" "sqlsubnet" {
  name                 = "subnet-mi"
  resource_group_name  = azurerm_resource_group.rsg.name
  virtual_network_name = azurerm_virtual_network.sqlvnet.name
  address_prefixes     = ["10.0.0.0/24"]

  delegation {
    name = "managedinstancedelegation"

    service_delegation {
      name    = "Microsoft.Sql/managedInstances"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action", "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "nsgassociation" {
  subnet_id                 = azurerm_subnet.sqlsubnet.id
  network_security_group_id = azurerm_network_security_group.sqlnsg.id
}

resource "azurerm_route_table" "sqlroute" {
  name                          = "routetable-mi"
  location                      = azurerm_resource_group.rsg.location
  resource_group_name           = azurerm_resource_group.rsg.name
  disable_bgp_route_propagation = false
  depends_on = [
    azurerm_subnet.sqlsubnet,
  ]
}

resource "azurerm_subnet_route_table_association" "sqlrassociation" {
  subnet_id      = azurerm_subnet.sqlsubnet.id
  route_table_id = azurerm_route_table.sqlroute.id
}

resource "azurerm_mssql_managed_instance" "sqlmi" {
  name                         = "managedsqldnatestinstance0204"
  resource_group_name          = azurerm_resource_group.rsg.name
  location                     = azurerm_resource_group.rsg.location
  administrator_login          = "mradministrator"
  administrator_login_password = "thisIsDog11"
  license_type                 = "BasePrice"
  subnet_id                    = azurerm_subnet.sqlsubnet.id
  sku_name                     = "GP_Gen5"
  vcores                       = 4
  storage_size_in_gb           = 32

  depends_on = [
    azurerm_subnet_network_security_group_association.nsgassociation,
    azurerm_subnet_route_table_association.sqlrassociation,
  ]
}