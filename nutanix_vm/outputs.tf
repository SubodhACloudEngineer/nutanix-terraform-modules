output "vm_name" {
  description = "Computed name of the provisioned VM. Matches the hostname set in Prism Central and (for Windows) the Sysprep computer name."
  value       = local.vm_name
}

output "vm_uuid" {
  description = "UUID of the provisioned VM in Prism Central. Use this for terraform import operations and for referencing the VM in other Nutanix resources."
  value = coalesce(
    try(nutanix_virtual_machine.this[0].id, null),
    try(nutanix_deploy_templates_v2.this[0].deployed_vms[0].ext_id, null),
  )
}

output "vm_ip" {
  description = "Primary IP address of the provisioned VM. Populated once Nutanix Guest Tools (NGT) reports the IP back to Prism Central after first boot. May be null immediately after apply if the VM has not yet completed first boot."
  value = try(
    nutanix_virtual_machine.this[0].nic_list_status[0].ip_endpoint_list[0].ip,
    try(nutanix_deploy_templates_v2.this[0].deployed_vms[0].nic_list[0].ip_endpoint_list[0].ip, null),
  )
}

output "source_type_used" {
  description = "The source_type value that was used for this deployment. Either 'template' or 'image'. Useful for debugging and in smoke tests."
  value       = var.source_type
}

# ── Unit-test helper outputs ──────────────────────────────────────────────────────────────────────────

output "umicore_location" {
  value = var.UMICORE_LOCATION
}

output "umicore_environment" {
  value = var.environment
}

output "vm_name_local" {
  value = local.vm_name
}

output "categories_applied" {
  value = local.vm_categories
}

output "os_disk_label" {
  value = local.os_disk_label
}

output "nic_name_local" {
  value = local.nic_name
}

output "data_disk_labels" {
  value = local.data_disk_labels
}

output "source_type_local" {
  value = var.source_type
}

output "num_vcpus_per_socket" {
  value = var.num_vcpus_per_socket
}

output "memory_size_mib" {
  value = var.memory_size_mib
}

output "category_backup" {
  value = var.category_backup
}

output "ad_join_local" {
  value = var.ad_join
}
