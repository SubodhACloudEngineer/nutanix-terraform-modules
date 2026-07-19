output "vm_name" {
  description = "Computed name of the provisioned VM. Matches the hostname set in Prism Central and (for Windows) the Sysprep computer name."
  value       = local.vm_name
}

output "vm_uuid" {
  description = "UUID (ext_id) of the provisioned VM in Prism Central. Use this for terraform import operations and for referencing the VM in other Nutanix resources."
  value = coalesce(
    try(nutanix_virtual_machine_v2.this[0].ext_id, null),
    try(nutanix_deploy_templates_v2.this[0].id, null),
  )
}

output "vm_ip" {
  description = <<-EOT
    Primary IP address of the provisioned VM, once Nutanix Guest Tools (NGT)
    reports it back to Prism Central after first boot.
    NOTE: the exact computed attribute path for the learned IP on
    nutanix_virtual_machine_v2 is not exercised by the provider's acceptance
    tests and cannot be confirmed without a real apply. It is therefore left as
    null pending the Sprint 4 integration test, at which point the confirmed
    path (expected under nics[].nic_network_info[].virtual_ethernet_nic_network_info[].ipv4_info)
    will be wired in. The output is kept so the module contract is stable.
  EOT
  value       = null
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
