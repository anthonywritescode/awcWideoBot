# terraform

to set up this module with terraform, add the oci provider to your terraform:

```terraform
variable "oci_tenancy_ocid" { type = string }
variable "oci_user_ocid" { type = string }
variable "oci_private_key" { type = string }
variable "oci_fingerprint" { type = string }
variable "oci_region" { type = string }

variable "discord_bot_config" { type = string }
variable "discord_bot_token" { type = string }

provider "oci" {
  tenancy_ocid = var.oci_tenancy_ocid
  user_ocid    = var.oci_user_ocid
  private_key  = var.oci_private_key
  fingerprint  = var.oci_fingerprint
  region       = var.oci_region
}
```

then use the module (in this case I have a submodule at `./awcWideoBot`)

```terraform
module "awcWideoBot" {
  source = "./awcWideoBot/terraform"

  oci_tenancy_ocid = var.oci_tenancy_ocid
  discord_bot_config = var.discord_bot_config
  discord_bot_token = var.discord_bot_token
}
```
