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
    Primary IPv4 address of the provisioned VM, learned from the guest once
    the NIC has an address.

    CURRENTLY RETURNS NULL BY DESIGN. The exact computed attribute path for
    the learned IP on nutanix_virtual_machine_v2 is not exercised by the
    provider's acceptance tests and cannot be confirmed without a real apply.
    The 2.4.2 provider binary contains both `nic_network_info` and
    `network_info` shapes alongside `ipv4_info`, `ipv4_config` and
    `learned_ip_addresses`, so guessing is not safe: a reference to an
    attribute that does not exist in the schema is a STATIC error that
    try() cannot suppress, and it would fail `terraform validate` for every
    consumer of this module.

    TO RESOLVE (first real apply, see Step 4 of the apply test plan):
      terraform show -json | jq '.values.root_module.child_modules[].resources[]
        | select(.type=="nutanix_virtual_machine_v2") | .values.nics'
    Read the actual returned structure, then replace the null below with the
    single confirmed path and bump the module minor version.

    The output is kept so the module contract stays stable for callers.
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
