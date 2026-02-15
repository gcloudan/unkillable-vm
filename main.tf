terraform {
  required_providers {
    oci = {
      source  = "hashicorp/oci"
      version = ">= 5.0.0"
    }
  }
}

provider "oci" {
  config_file_profile = "DEFAULT"
}

# --- 1. CONFIGURATION ---
variable "compartment_ocid" {
  default = "ocid1.tenancy.oc1..aaaaaaaaujbaspt2ecz6xpxyisgt2dekufaivdsikgrmn6ezrhrk2dvm56oa"
}

variable "ssh_public_key" {
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZWUfKvTJ/T6pq1b6WMw04u8weqEdJmeAELp9jDyhrAXn8HBvGGl9sY3qgP94B/8Kat0cu99UKWoqViTfarDMcnbYo9TmWqJ81wjcGX8XQRzzA3xkFEiQr4IHinNA1bMW/QxVjOPROHECND43ByMtojeGPjgW6y1xr3/HPQ0LYTlep4/0tb5an/gQGLe9rTiGHZY/iBmEhFkIbmb3Te9ceQXvIrZ3n9lJmrAGCBu9tq6wbmIt7tkw+/C20JAtOr3CDuzn29DtWXdNLwnhvjtdSYjuRW4B7NH8glOEAQucPsvx59k7WifhfCWjphRv9ocMzikHXghYEkET7ONTGUqb3 ssh-key-2026-02-14"
}

# --- 2. MARKETPLACE RESOLVER & SUBSCRIPTION ---
# Using the exact ID you found in CloudShell
variable "rocky_listing_id" {
  default = "ocid1.appcataloglisting.oc1..aaaaaaaazht7vduko4ld3vd36b4kcud2d23pbupi3f5oq2ukl22aod643buq"
}

data "oci_core_app_catalog_listing_resource_versions" "rocky_versions" {
  listing_id = var.rocky_listing_id
}

# 2a. Fetch the Agreement for this version
resource "oci_core_app_catalog_listing_resource_version_agreement" "rocky_agreement" {
  listing_id               = var.rocky_listing_id
  listing_resource_version = data.oci_core_app_catalog_listing_resource_versions.rocky_versions.app_catalog_listing_resource_versions[0].listing_resource_version
}

# 2b. Electronically "Sign" the Agreement
resource "oci_core_app_catalog_subscription" "rocky_subscription" {
  compartment_id           = var.compartment_ocid
  listing_id               = var.rocky_listing_id
  listing_resource_version = data.oci_core_app_catalog_listing_resource_versions.rocky_versions.app_catalog_listing_resource_versions[0].listing_resource_version
  oracle_terms_of_use_link = oci_core_app_catalog_listing_resource_version_agreement.rocky_agreement.oracle_terms_of_use_link
  signature                = oci_core_app_catalog_listing_resource_version_agreement.rocky_agreement.signature
  time_retrieved           = oci_core_app_catalog_listing_resource_version_agreement.rocky_agreement.time_retrieved
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# --- 3. NETWORKING ---
resource "oci_core_vcn" "main_vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "primary-network-vcn"
  cidr_block     = "10.0.0.0/16"
  dns_label      = "primaryvcn"
}

resource "oci_core_internet_gateway" "main_gateway" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main_vcn.id
  display_name   = "internet-gateway"
  enabled        = true
}

resource "oci_core_default_route_table" "main_route_table" {
  manage_default_resource_id = oci_core_vcn.main_vcn.default_route_table_id
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main_gateway.id
  }
}

resource "oci_core_subnet" "main_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main_vcn.id
  display_name      = "public-subnet-1"
  cidr_block        = "10.0.0.0/24"
  dns_label         = "sub01"
  route_table_id    = oci_core_vcn.main_vcn.default_route_table_id
}

# --- 4. SECURITY ---
resource "oci_core_network_security_group" "critical_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main_vcn.id
  display_name   = "critical-node-nsg"
}

resource "oci_core_network_security_group_security_rule" "ssh_rule" {
  network_security_group_id = oci_core_network_security_group.critical_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# --- 5. THE ROCKY SERVER ---
resource "oci_core_instance" "critical_server" {
  # Wait until the subscription is confirmed before building the server
  depends_on          = [oci_core_app_catalog_subscription.rocky_subscription]
  
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "instance-rocky-node"
  shape               = "VM.Standard.A1.Flex"

  source_details {
    source_type = "image"
    source_id   = data.oci_core_app_catalog_listing_resource_versions.rocky_versions.app_catalog_listing_resource_versions[0].listing_resource_id
    boot_volume_size_in_gbs = 200
  }

  shape_config {
    ocpus         = 4
    memory_in_gbs = 24
  }

  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
  }

  create_vnic_details {
    subnet_id = oci_core_subnet.main_subnet.id
    assign_public_ip = true
    nsg_ids = [oci_core_network_security_group.critical_nsg.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(<<-CLOUDINIT
      #cloud-config
      package_update: true
      packages:
        - golang
        - htop
        - git
    CLOUDINIT
    )
  }
}

output "rocky_ip" {
  value = oci_core_instance.critical_server.public_ip
}
