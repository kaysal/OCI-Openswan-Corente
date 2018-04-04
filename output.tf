data "oci_core_vnic" "SecondaryVnic" {
  count = "${var.SECONDARY_VNIC_COUNT}"
  vnic_id = "${element(oci_core_vnic_attachment.SECONDARY_VNIC_ATTACHMENT.*.vnic_id, count.index)}"
}

output "openswan_instance_primary_vnic_ip" {
  value = ["${oci_core_instance.OPENSWAN_INSTANCE.public_ip}",
           "${oci_core_instance.OPENSWAN_INSTANCE.private_ip}"]
}

output "openswan_instance_secondary_vnic_public_ip" {
  value = ["${data.oci_core_vnic.SecondaryVnic.*.public_ip_address}"]
}

output "openswan_instance_secondary_vnic_private_ip" {
  value = ["${data.oci_core_vnic.SecondaryVnic.*.private_ip_address}"]
}

output "bastion_instance_ip" {
  value = ["${oci_core_instance.BASTION_INSTANCE.public_ip}",
           "${oci_core_instance.BASTION_INSTANCE.private_ip}"]
}

output "vm_instance_ip" {
  value = ["${oci_core_instance.VM_INSTANCE.public_ip}",
           "${oci_core_instance.VM_INSTANCE.private_ip}"]
}
