provider "oci" {
  tenancy_ocid = "${var.tenancy_ocid}"
  user_ocid = "${var.user_ocid}"
  fingerprint = "${var.fingerprint}"
  private_key_path = "${var.private_key_path}"
  region = "${var.region}"
}

data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}

resource "oci_core_virtual_network" "VCN" {
  cidr_block = "${var.VCN}"
  compartment_id = "${var.compartment_ocid}"
  display_name = "VCN"
}

# INTERNET GATEWAY
#--------------------------------------
resource "oci_core_internet_gateway" "INTERNET_GW" {
  compartment_id = "${var.compartment_ocid}"
  display_name = "INTERNET_GW"
  vcn_id = "${oci_core_virtual_network.VCN.id}"
}

# SECURITY LISTS
#--------------------------------------
resource "oci_core_security_list" "PUBLIC_SECLIST" {
  compartment_id = "${var.compartment_ocid}"
  display_name = "PUBLIC_SECLIST"
  vcn_id = "${oci_core_virtual_network.VCN.id}"

  egress_security_rules = [
    {
      destination = "0.0.0.0/0"
      protocol = "6"
    },
    {
      destination = "0.0.0.0/0"
      protocol = "17"
    },
    {
      destination = "0.0.0.0/0"
      protocol = "1"
    }
  ]

  ingress_security_rules = [
    {
      protocol = "6"
      source = "0.0.0.0/0"
    },
    {
      protocol = "17"
      source = "0.0.0.0/0"
    },
    {
      protocol = "1"
      source = "0.0.0.0/0"
    }
  ]
}

resource "oci_core_security_list" "LAN_SECLIST" {
  compartment_id = "${var.compartment_ocid}"
  display_name = "LAN_SECLIST"
  vcn_id = "${oci_core_virtual_network.VCN.id}"

  egress_security_rules = [
    {
      protocol = "all"
      destination = "${var.LOCAL_LAN_SUBNET}"
    },
    {
      protocol = "all"
      destination = "${var.REMOTE_LAN_SUBNET}"
    },
    {
      protocol = "all"
      destination = "${var.PUBLIC_SUBNET}"
    }
  ]

  ingress_security_rules = [
    {
      protocol = "all"
      source = "${var.LOCAL_LAN_SUBNET}"
    },
    {
      protocol = "all"
      source = "${var.REMOTE_LAN_SUBNET}"
    },
    {
      protocol = "all"
      source = "${var.PUBLIC_SUBNET}"
    }
  ]
}

# INTERNET ROUTE TABLE
#--------------------------------------
resource "oci_core_route_table" "INTERNET_ROUTE" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id = "${oci_core_virtual_network.VCN.id}"
  display_name = "INTERNET_ROUTE"
  route_rules {
    cidr_block = "0.0.0.0/0"
    network_entity_id = "${oci_core_internet_gateway.INTERNET_GW.id}"
  }
}

# PUBLIC SUBNET
#--------------------------------------
resource "oci_core_subnet" "PUBLIC_SUBNET" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
  cidr_block = "${var.PUBLIC_SUBNET}"
  display_name = "PUBLIC_SUBNET"
  compartment_id = "${var.compartment_ocid}"
  vcn_id = "${oci_core_virtual_network.VCN.id}"
  route_table_id = "${oci_core_route_table.INTERNET_ROUTE.id}"
  security_list_ids = ["${oci_core_security_list.PUBLIC_SECLIST.id}"]
  dhcp_options_id = "${oci_core_virtual_network.VCN.default_dhcp_options_id}"
}

# CREATE OPENSWAN INSTANCE
#--------------------------------------
resource "oci_core_instance" "OPENSWAN_INSTANCE" {
    availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
    compartment_id = "${var.compartment_ocid}"
    display_name = "OPENSWAN_INSTANCE"
    image = "${var.OL74_IMAGE_OCID}"
    shape = "${var.INSTANCE_SHAPE}"
    create_vnic_details {
        subnet_id = "${oci_core_subnet.PUBLIC_SUBNET.id}"
        private_ip = "192.168.1.2"
        display_name = "OPENSWAN_PRIMARY_VNIC"
        assign_public_ip = true
        skip_source_dest_check = true
    }
    metadata {
        ssh_authorized_keys = "${var.public_key}"
        user_data = "${base64encode(file(var.BootStrapFile))}"
    }
    timeouts {
        create = "10m"
    }
}

# VPN ROUTE TABLE
#--------------------------------------
resource "oci_core_route_table" "VPN_ROUTE" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id = "${oci_core_virtual_network.VCN.id}"
  display_name = "VPN_ROUTE"
}

# LOCAL LAN SUBNET
#--------------------------------------
resource "oci_core_subnet" "LOCAL_LAN_SUBNET" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
  cidr_block = "${var.LOCAL_LAN_SUBNET}"
  display_name = "LOCAL_LAN_SUBNET"
  compartment_id = "${var.compartment_ocid}"
  vcn_id = "${oci_core_virtual_network.VCN.id}"
  route_table_id = "${oci_core_route_table.VPN_ROUTE.id}"
  security_list_ids = ["${oci_core_security_list.LAN_SECLIST.id}"]
  dhcp_options_id = "${oci_core_virtual_network.VCN.default_dhcp_options_id}"
  prohibit_public_ip_on_vnic = "true"
}

# SECONDARY VNIC ATTACHMENT
#--------------------------------------
resource "oci_core_vnic_attachment" "SECONDARY_VNIC_ATTACHMENT" {
  instance_id = "${oci_core_instance.OPENSWAN_INSTANCE.id}"
  display_name = "SECONDARY_VNIC_ATTACHMENT_${count.index}"
  create_vnic_details {
    subnet_id = "${oci_core_subnet.LOCAL_LAN_SUBNET.id}"
    private_ip = "192.168.1.200"
    display_name = "SECONDARY_VNIC_${count.index}"
    assign_public_ip = false
    skip_source_dest_check = true
  }
  count = "${var.SECONDARY_VNIC_COUNT}"
}

# CREATE BASTION INSTANCE
#--------------------------------------
resource "oci_core_instance" "BASTION_INSTANCE" {
    availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
    compartment_id = "${var.compartment_ocid}"
    display_name = "BASTION_INSTANCE"
    image = "${var.OL74_IMAGE_OCID}"
    shape = "${var.INSTANCE_SHAPE}"
    create_vnic_details {
        subnet_id = "${oci_core_subnet.PUBLIC_SUBNET.id}"
        private_ip = "192.168.1.10"
        display_name = "BASTION_PRIMARY_VNIC"
        assign_public_ip = true
        skip_source_dest_check = false
    }
    metadata {
        ssh_authorized_keys = "${var.public_key}"
    }
    timeouts {
        create = "10m"
    }
}

# CREATE VM INSTANCE
#--------------------------------------
resource "oci_core_instance" "VM_INSTANCE" {
    availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[0],"name")}"
    compartment_id = "${var.compartment_ocid}"
    display_name = "VM_INSTANCE"
    image = "${var.OL74_IMAGE_OCID}"
    shape = "${var.INSTANCE_SHAPE}"
    create_vnic_details {
        subnet_id = "${oci_core_subnet.LOCAL_LAN_SUBNET.id}"
        private_ip = "192.168.1.150"
        display_name = "VM_PRIMARY_VNIC"
        assign_public_ip = false
        skip_source_dest_check = false
    }
    metadata {
        ssh_authorized_keys = "${var.public_key}"
    }
    timeouts {
        create = "10m"
    }
}
