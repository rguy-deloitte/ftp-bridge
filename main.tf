terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "8.13.0"
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
    #Required
    compartment_id = var.compartment_id
    vcn_id = oci_core_vcn.ftpb_vcn.id

    #Optional
    block_traffic = true
    display_name = "ftp-bridge-natg"
    # public_ip_id = oci_core_public_ip.test_public_ip.id
    # route_table_id = oci_core_route_table.test_route_table.id

    # defined_tags = {"Operations.CostCenter"= "42"}
    # freeform_tags = {"Department"= "Finance"}
}

resource "oci_functions_application" "ftpb_fnapplication" {
  #Required
  compartment_id = var.compartment_id
  display_name   = "ftp-bridge-application"
  subnet_ids     = [oci_core_subnet.ftpb_subnet.id]

  #Optional
  # config                     = var.config
  # syslog_url                 = var.syslog_url
  # network_security_group_ids = [oci_core_network_security_group.test_network_security_group.id]
  image_policy_config {
    #Required
    is_policy_enabled = false

    #Optional
    #key_details {
      #Required
    #  kms_key_id = var.kms_key_ocid
    #}
  }

  # trace_config {
  #  domain_id  = var.application_trace_config.domain_id
  #  is_enabled = var.application_trace_config.is_enabled
  # }

  # shape = var.application_shape

#  security_attributes = {
#    "oracle-zpr.sensitivity.value" = "low"
#    "oracle-zpr.sensitivity.mode" = "enforce"
#  }
  
 # logging {

    #Optional
#    line_format = var.application_logging_line_format
#  }
}

# resource "oci_functions_function" "test_function" {
#   #Required
#   application_id = oci_functions_application.ftpb_fnapplication.id
#   display_name   = "ftp-bridge-function"
#   image          = var.function_image
#   memory_in_mbs  = var.function_memory_in_mbs

#   #Optional
#   config             = var.config
#   image_digest       = var.function_image_digest
#   timeout_in_seconds = var.function_timeout_in_seconds
#   trace_config {
#     is_enabled = var.function_trace_config.is_enabled
#   }

#   provisioned_concurrency_config {
#     strategy = "CONSTANT"
#     count = 40
#   }

#   detached_mode_timeout_in_seconds = var.function_detached_mode_timeout_in_seconds
#   failure_destination {
#     kind = "QUEUE"
#     channel_id = "failure123"
#     queue_id = oci_queue_queue.test_queue.id
#   }

#   success_destination {
#     kind = "STREAM"
#     stream_id = oci_streaming_stream.test_stream.id
#   }
# }