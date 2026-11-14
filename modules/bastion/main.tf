resource "azurerm_network_security_group" "bastion" {
  name                = "nsg-bastion-${var.name_prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_network_security_rule" "ssh" {
  name                        = "allow-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.allowed_ssh_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-${var.name_prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_network_interface" "bastion" {
  name                = "nic-bastion-${var.name_prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_network_interface_security_group_association" "bastion" {
  network_interface_id      = azurerm_network_interface.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

# postgresql-client ships psql, pg_dump and pg_restore, which is the whole
# point of this VM: reach the private server and replay the Strapi dump.
# Node.js 22 comes from NodeSource because Ubuntu 24.04 still ships 18.
# pgweb is the browser-based explorer (schema tree, SQL editor, CSV/JSON
# export); it binds to 127.0.0.1 only, so it is reachable solely through an
# SSH tunnel and never carries credentials of its own.
resource "azurerm_linux_virtual_machine" "bastion" {
  name                = "vm-bastion-${var.name_prefix}-${var.suffix}"
  computer_name       = "bastion-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids           = [azurerm_network_interface.bastion.id]
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOT
    #cloud-config

    write_files:
      - path: /etc/systemd/system/pgweb.service
        permissions: "0644"
        content: |
          [Unit]
          Description=pgweb PostgreSQL explorer (loopback only)
          Documentation=https://github.com/sosedoff/pgweb
          After=network-online.target
          Wants=network-online.target

          [Service]
          Type=simple
          User=pgweb
          Group=pgweb
          Environment=HOME=/var/lib/pgweb
          ExecStart=/usr/local/bin/pgweb --bind 127.0.0.1 --listen 8081 --skip-open --sessions
          Restart=on-failure
          RestartSec=5
          NoNewPrivileges=true
          PrivateTmp=true
          ProtectHome=true
          ProtectSystem=strict

          [Install]
          WantedBy=multi-user.target

    runcmd:
      - |
        set -eux
        export DEBIAN_FRONTEND=noninteractive
        apt-get -y -o DPkg::Lock::Timeout=600 update
        apt-get -y -o DPkg::Lock::Timeout=600 install postgresql-client ca-certificates curl gnupg unzip

        # Node.js 22 LTS. The NodeSource script installs its own apt repo pinned
        # to the 22.x line, so the bastion tracks 22 security releases.
        curl -fsSL https://deb.nodesource.com/setup_22.x -o /tmp/nodesource_setup.sh
        bash /tmp/nodesource_setup.sh
        apt-get -y -o DPkg::Lock::Timeout=600 install nodejs

        # pgweb v0.17.0, static linux/amd64 binary (the VM size is x86_64).
        curl -fsSL -o /tmp/pgweb.zip \
          https://github.com/sosedoff/pgweb/releases/download/v0.17.0/pgweb_linux_amd64.zip
        unzip -oq /tmp/pgweb.zip -d /tmp
        install -m 0755 /tmp/pgweb_linux_amd64 /usr/local/bin/pgweb

        id -u pgweb >/dev/null 2>&1 || \
          useradd --system --create-home --home-dir /var/lib/pgweb --shell /usr/sbin/nologin pgweb
        systemctl daemon-reload
        systemctl enable --now pgweb.service
  EOT
  )

  tags = var.tags

  depends_on = [azurerm_network_interface_security_group_association.bastion]
}
