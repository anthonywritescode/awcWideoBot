variable "oci_tenancy_ocid" { type = string }
variable "discord_bot_config" { type = string }
variable "discord_bot_token" { type = string }

data "oci_identity_availability_domains" "oci" {
  compartment_id = var.oci_tenancy_ocid
}

resource "oci_identity_compartment" "wideo_bot" {
  compartment_id = var.oci_tenancy_ocid
  name           = "wideo-bot"
  description    = "wideo-bot"
}

resource "oci_kms_vault" "wideo_bot" {
  compartment_id = oci_identity_compartment.wideo_bot.id
  display_name   = "wideo_bot"
  vault_type     = "DEFAULT"
}

resource "oci_kms_key" "wideo_bot" {
  compartment_id      = oci_identity_compartment.wideo_bot.id
  display_name        = "wideo_bot"
  management_endpoint = oci_kms_vault.wideo_bot.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32
  }
}

resource "oci_vault_secret" "discord_bot_config" {
  compartment_id = oci_identity_compartment.wideo_bot.id
  vault_id       = oci_kms_vault.wideo_bot.id
  key_id         = oci_kms_key.wideo_bot.id
  secret_name    = "discord-bot-config"

  secret_content {
    content_type = "BASE64"

    content = base64encode(var.discord_bot_config)
  }
}

resource "oci_vault_secret" "discord_bot_token" {
  compartment_id = oci_identity_compartment.wideo_bot.id
  vault_id       = oci_kms_vault.wideo_bot.id
  key_id         = oci_kms_key.wideo_bot.id
  secret_name    = "discord-bot-token"

  secret_content {
    content_type = "BASE64"

    content = base64encode(var.discord_bot_token)
  }
}

resource "oci_core_vcn" "wideo_bot" {
  compartment_id = oci_identity_compartment.wideo_bot.id
  cidr_blocks    = ["10.0.0.0/24"]
}

resource "oci_core_internet_gateway" "wideo_bot" {
  compartment_id = oci_identity_compartment.wideo_bot.id
  vcn_id         = oci_core_vcn.wideo_bot.id
}

resource "oci_core_route_table" "wideo_bot" {
  compartment_id = oci_identity_compartment.wideo_bot.id
  vcn_id         = oci_core_vcn.wideo_bot.id

  route_rules {
    network_entity_id = oci_core_internet_gateway.wideo_bot.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}


resource "oci_core_subnet" "wideo_bot" {
  cidr_block     = "10.0.0.0/24"
  compartment_id = oci_identity_compartment.wideo_bot.id
  vcn_id         = oci_core_vcn.wideo_bot.id
  route_table_id = oci_core_route_table.wideo_bot.id
}

resource "oci_core_security_list" "wideo_bot" {
  compartment_id = oci_identity_compartment.wideo_bot.id
  vcn_id         = oci_core_vcn.wideo_bot.id

  egress_security_rules {
    stateless        = false
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }


  ingress_security_rules {
    stateless   = false
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 22
      max = 22
    }
  }
  ingress_security_rules {
    stateless   = false
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "1"
    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    stateless   = false
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    protocol    = "1"
    icmp_options {
      type = 3
    }
  }
}

data "oci_core_images" "ubuntu_22_04" {
  compartment_id           = oci_identity_compartment.wideo_bot.id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "wideo_bot" {
  availability_domain = data.oci_identity_availability_domains.oci.availability_domains[0].name
  compartment_id      = oci_identity_compartment.wideo_bot.id
  shape               = "VM.Standard.A1.Flex"
  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }
  source_details {
    source_id   = data.oci_core_images.ubuntu_22_04.images[0].id
    source_type = "image"
  }

  create_vnic_details {
    assign_public_ip = true
    subnet_id        = oci_core_subnet.wideo_bot.id
  }
  metadata = {
    ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDTOQGOr6sEmA1vL7POTauIq0vhHUVv/G1MpN0px1GC0a/NzdS7290s936yOP8HMw6L329iJMpkiUEJMgSnA/MhzWjMMm+9HoqtwN1o4Tih7aAZYPMVoUamvdpWT1eVXtCTViiQcd9oOkj1o1Jo+NX2oKyDzfPQYr3wmQ118DmQNc+S5QeYfdfbbO+RzThU2c98FfSefQVUSdwyUCh1M7kxWn7N9Z7/lwdzAQm5NA6OAmacAPUJ0+TDflhgGXmCqFsmNunyaXKDiL6sZ8mELEZEm23t2ND0HORGooHdT65gKZ+rbxk9Gct7zXE+HjPg5uzV2eXiaRW2uZHqVh5YkuuF anthony@anthony-VirtualBox"
    user_data = base64encode(
      replace(
        file("${path.module}/data/cloud-init.sh"),
        "VAULT_ID",
        oci_kms_vault.wideo_bot.id,
      ),
    )
  }
  preserve_boot_volume = false
}

resource "oci_identity_dynamic_group" "wideo_bot" {
  compartment_id = var.oci_tenancy_ocid
  name           = "wideo_bot"
  description    = "wideo_bot"
  matching_rule  = "instance.id = '${oci_core_instance.wideo_bot.id}'"
}

resource "oci_identity_policy" "vault_policy" {
  compartment_id = var.oci_tenancy_ocid
  description    = "wideo_bot"
  name           = "wideo_bot"
  statements = [
    "allow dynamic-group wideo_bot to read secret-family in compartment id ${oci_identity_compartment.wideo_bot.id} where target.secret.name = '${oci_vault_secret.discord_bot_config.secret_name}'",
    "allow dynamic-group wideo_bot to read secret-family in compartment id ${oci_identity_compartment.wideo_bot.id} where target.secret.name = '${oci_vault_secret.discord_bot_token.secret_name}'",
  ]
}
