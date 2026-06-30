locals {
  # VM name: explicit override takes precedence over the computed naming
  # convention. Computed form is 10 chars (e.g. "hob-as-0013"), safely
  # within the 15-char Windows NetBIOS hostname limit. The override path
  # is unrestricted by the module but Nutanix AHV enforces its own limits.
  vm_name = var.vm_name_override != null ? var.vm_name_override : lower(format(
    "%s-%s-%04d",
    upper(var.UMICORE_LOCATION),
    upper(var.usage_code),
    var.sequence_number,
  ))

  # Sub-resource names derived from vm_name for consistency.
  os_disk_label     = "${local.vm_name}-osdisk"
  nic_name          = "${local.vm_name}-nic"
  nic_ipconfig_name = "${local.vm_name}-nic-ipconfig"

  data_disk_labels = [
    for index, disk in var.data_disks :
    "${local.vm_name}-datadisk-${format("%02d", index + 1)}"
  ]

  # Mandatory categories merged with any extra tags. extra_tags values
  # take precedence on key clashes (merge() last-wins behaviour); in
  # practice extra_tags should not override mandatory categories.
  vm_categories = merge(
    {
      BusinessUnit    = var.category_business_unit
      Environment     = var.category_environment
      Criticality     = var.category_criticality
      Recharge        = var.category_recharge
      PrimaryFunction = var.category_primary_function
      Application     = var.category_application
      Description     = var.category_description
      BUResponsible   = var.category_bu_responsible
      ITResponsible   = var.category_it_responsible
      Backup          = var.category_backup
    },
    var.extra_tags,
  )

  # Guest customisation flags.
  apply_sysprep    = var.os_type == "windows" && var.sysprep_xml != null
  apply_cloud_init = var.os_type == "linux" && var.cloud_init_userdata != null

  # Source resolution.
  use_template_path = var.source_type == "template"
  use_image_path    = var.source_type == "image"
}
