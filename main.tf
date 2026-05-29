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
  config_file_profile = "FTP-BRIDGE-TF"
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

# resource "oci_core_route_table" "ftpb_private_rt" {
#     compartment_id = var.compartment_id
#     vcn_id         = oci_core_vcn.ftpb_vcn.id
#     display_name   = "ftp-bridge-private-rt"

#     route_rules {
#         destination_type  = "CIDR_BLOCK"
#         destination       = "0.0.0.0/0"
#         network_entity_id = oci_core_nat_gateway.ftpb_nat_gateway.id
#     }

#     route_rules {
#         destination_type  = "SERVICE_CIDR_BLOCK"
#         destination = "all-lhr-services-in-oracle-services-network"
#         network_entity_id = oci_core_service_gateway.ftpb_service_gateway.id
#     }
# }

resource "oci_core_default_route_table" "default-route-table" {
  compartment_id = var.compartment_id
  manage_default_resource_id = oci_core_vcn.ftpb_vcn.default_route_table_id

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

# resource "oci_core_route_table_attachment" "ftpb_subnet_rt_attach" {
#     subnet_id      = oci_core_subnet.ftpb_subnet.id
#     route_table_id = oci_core_route_table.ftpb_private_rt.id
# }

resource "oci_functions_application" "ftpb_fnapplication" {
  compartment_id = var.compartment_id
  display_name   = "ftp-bridge-application"
  subnet_ids     = [oci_core_subnet.ftpb_subnet.id]

  image_policy_config {
    is_policy_enabled = false
  }

  # trace_config {
  #  domain_id  = var.application_trace_config.domain_id
  #  is_enabled = var.application_trace_config.is_enabled
  # }

  # logging {
      #Optional
  #    line_format = var.application_logging_line_format
  #  }
}

resource "oci_functions_function" "ftpb_function" {
  application_id = oci_functions_application.ftpb_fnapplication.id
  display_name   = "ftp-bridge-function"
  image          = var.image_path
  memory_in_mbs  = 128

  trace_config {
    is_enabled = true
  }
}

resource "oci_resource_scheduler_schedule" "ftpb-out-schedule" {
  #Required
  action             = "START_RESOURCE"
  compartment_id     = var.compartment_id
  recurrence_details = "0 * * * *"
  recurrence_type    = "CRON"

  resources {
    id = oci_functions_function.ftpb_function.id
    parameters {
      parameter_type = "BODY"
      value = [jsonencode({
        source = ".hdfc.source.env"
      })]
    }
  }

  #Optional
  description   = "Schedule to run ftp-bridge inbound transfer at 0 minutes past each hour"
  display_name  = "ftp-bridge-inbound-hourly-0"
}

resource "oci_resource_scheduler_schedule" "ftpb-in-schedule-0" {
  #Required
  action             = "START_RESOURCE"
  compartment_id     = var.compartment_id
  recurrence_details = "10 * * * *"
  recurrence_type    = "CRON"

  resources {
    id = oci_functions_function.ftpb_function.id
    parameters {
      parameter_type = "BODY"
      value = [jsonencode({
        source = ".hdfc.source.env"
      })]
    }
  }

  #Optional
  description   = "Schedule to run ftp-bridge inbound transfer at 10 minutes past each hour"
  display_name  = "ftp-bridge-inbound-hourly-10"
}

resource "oci_resource_scheduler_schedule" "ftpb-in-schedule-1" {
  #Required
  action             = "START_RESOURCE"
  compartment_id     = var.compartment_id
  recurrence_details = "40 * * * *"
  recurrence_type    = "CRON"

  resources {
    id = oci_functions_function.ftpb_function.id
    parameters {
      parameter_type = "BODY"
      value = [jsonencode({
        source = ".hdfc.source.env"
      })]
    }
  }

  #Optional
  description   = "Schedule to run ftp-bridge inbound transfer at 40 minutes past each hour"
  display_name  = "ftp-bridge-inbound-hourly-40"
}

resource "oci_identity_dynamic_group" "ftpb-dynamic_group" {
    #Required
    compartment_id = var.tenancy_ocid
    description = "Dynamic group for ftp-bridge schedules which need permissions to invoke OCI functions"
    matching_rule = "ANY {resource.id='${oci_resource_scheduler_schedule.ftpb-out-schedule.id}', resource.id='${oci_resource_scheduler_schedule.ftpb-in-schedule-0.id}', resource.id='${oci_resource_scheduler_schedule.ftpb-in-schedule-1.id}'}"
    name = "ftp-bridge-schedule-dynamic-group"
}

resource "oci_identity_policy" "ftpb-schedule-policy" {
    #Required
    compartment_id = var.tenancy_ocid
    description = "Policy to allow ftp-bridge schedules to invoke OCI functions"
    name = "ftp-bridge-schedule-policy"
    statements = ["Allow dynamic-group ${oci_identity_dynamic_group.ftpb-dynamic_group.name} to manage functions-family in tenancy"]
}

# resource "oci_logging_log_group" "ftpb_log_group" {
#   #Required
#   compartment_id = var.compartment_id
#   display_name   = "ftp-bridge-loggroup"

#   lifecycle {
#     ignore_changes = [ defined_tags ]
#   }
# }

resource "oci_logging_log" "ftpb-log" {
    #Required
    display_name = "ftp-bridge-log"
    log_group_id = var.logging_group_id
    log_type = "SERVICE"

    #Optional
    configuration {
        #Required
        source {
            #Required
            category = "invoke"
            resource = oci_functions_application.ftpb_fnapplication.id
            service = "Functions"
            source_type = "OCISERVICE"

            #Optional
            #parameters = var.log_configuration_source_parameters
        }
    }

    is_enabled = "true"
    retention_duration = "30"
}