variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "public_key" {}
variable "compartment_ocid" {}
variable "region" {}

variable "VCN" {
  default = "192.168.1.0/24"
}

variable "PUBLIC_SUBNET" {
  default = "192.168.1.0/25"
}

variable "LOCAL_LAN_SUBNET" {
  default = "192.168.1.128/25"
}

variable "REMOTE_LAN_SUBNET" {
  default = "172.16.1.0/24"
}

variable "UBUNTU1404_IMAGE_OCID" {}

variable "OL74_IMAGE_OCID" {}

variable "INSTANCE_SHAPE" {
    default = "VM.Standard1.2"
}

variable "SECONDARY_VNIC_COUNT" {
    default = 1
}

variable "BootStrapFile" {
  default = "./userdata/bootstrap"
}
