variable "compartment_id" {
  description = "OCID from your tenancy page"
  type        = string
}

variable "region" {
  description = "region where you have OCI tenancy"
  type        = string
  default     = "us-sanjose-1"
}

variable "tenancy_ocid" {
  description = "OCID from your tenancy page"
  type        = string
}

variable "logging_group_id" {
  description = "OCID of logging group to include log in"
  type        = string
}