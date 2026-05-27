terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "8.15.0"
    }
  }
}

provider "oci" {
  region              = var.region
  auth                = "SecurityToken"
  config_file_profile = "ftp-bridge-tf"
}

resource "oci_core_vcn" "ftpb_vcn" {
  dns_label      = "ftpbridge"
  cidr_block     = "10.0.0.0/24"
  compartment_id = var.compartment_id
  display_name   = "ftp-bridge-vcn"
}

resource "oci_core_subnet" "ftpb_subnet" {
  vcn_id                      = oci_core_vcn.ftpb_vcn.id
  cidr_block                  = "10.0.0.0/27"
  compartment_id              = var.compartment_id
  display_name                = "ftp-bridge-subnet"
  prohibit_public_ip_on_vnic  = true
  dns_label                   = "ftpbridgesubnet"
}

resource "oci_core_nat_gateway" "ftpb_nat_gateway" {
    compartment_id = var.compartment_id
    vcn_id = oci_core_vcn.ftpb_vcn.id
    block_traffic = false
    display_name = "ftp-bridge-natg"
}

resource "oci_core_service_gateway" "ftpb_service_gateway" {
    display_name = "ftp-bridge-servgate"
    compartment_id = var.compartment_id
    services {
        service_id = "ocid1.service.oc1.uk-london-1.aaaaaaaatwg7f5mnzoapfunl66n2qkp4ormiykqk3hiwksum63gcyjk7ysla"
    }
    vcn_id = oci_core_vcn.ftpb_vcn.id
}

# data "oci_core_services" "test_services" {
#   filter {
#     name   = "name"
#     values = ["All .* Services In Oracle Services Network"]
#     regex  = true
#   }
# }

# output "services" {
#   value = [data.oci_core_services.test_services.services]
# }

resource "oci_core_route_table" "ftpb_private_rt" {
    compartment_id = var.compartment_id
    vcn_id         = oci_core_vcn.ftpb_vcn.id
    display_name   = "ftp-bridge-private-rt"

    route_rules {
        destination_type  = "CIDR_BLOCK"
        destination       = "0.0.0.0/0"
        network_entity_id = oci_core_nat_gateway.ftpb_nat_gateway.id
    }

    route_rules {
        destination_type  = "SERVICE_CIDR_BLOCK"
        destination = "all-lhr-services-in-oracle-services-network"
        network_entity_id = oci_core_service_gateway.ftpb_service_gateway.id
    }
}

resource "oci_core_route_table_attachment" "ftpb_subnet_rt_attach" {
    subnet_id      = oci_core_subnet.ftpb_subnet.id
    route_table_id = oci_core_route_table.ftpb_private_rt.id
}
