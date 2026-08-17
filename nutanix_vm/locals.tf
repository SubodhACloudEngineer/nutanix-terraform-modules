locals {
  # VM name: explicit override takes precedence over the computed naming
  # convention. Computed form is 10 chars (e.g. "hob-as-0013"), safely
  # within the 15-char Windows NetBIOS hostname limit. The override path
  # is unrestricted by the module but Nutanix AHV enforces its own limits.
  #
  # NOTE ON CASE: the design document renders this convention in uppercase
  # (HOB-AS-0013) while this module emits lowercase (hob-as-0013), and
  # scripts/smoke-test.sh asserts lowercase. Code and test agree; the design
  # document does not. Resolve in design v0.3 rather than changing behaviour
  # here — a case change would force replacement of every existing VM.
  vm_name = var.vm_name_override != null ? var.vm_name_override : lower(format(
    "%s-%s-%04d",
    upper(var.UMICORE_LOCATION),
    upper(var.usage_code),
    var.sequence_number,
  ))

  # Sub-resource names derived from vm_name for consistency.
  #
  # NOTE: these are currently computed but not consumed. The v4 resource
  # schema (nutanix_virtual_machine_v2) does not expose per-disk or per-NIC
  # label arguments the way the v3 schema did. They are retained because the
  # unit tests assert them and because per-disk naming is expected to return
  # in a later provider release. If that does not materialise, remove them
  # and the associated variables in the next major version.
  os_disk_label     = "${local.vm_name}-osdisk"
  nic_name          = "${local.vm_name}-nic"
  nic_ipconfig_name = "${local.vm_name}-nic-ipconfig"

  data_disk_labels = [
    for index, disk in var.data_disks :
    "${local.vm_name}-datadisk-${format("%02d", index + 1)}"
  ]

  # -- Nutanix categories ---------------------------------------------------
  #
  # Category KEYS below must match the live Prism Central schema exactly.
  # Umicore uses an "Umi_" prefix. These names are resolved to ext_ids in
  # data.tf via nutanix_categories_v2, filtering on key + value; a key that
  # does not exist in Prism Central returns an empty list and fails at plan
  # time with an index error rather than a helpful message.
  #
  # VERIFY BEFORE FIRST PLAN: Umi_ITResponsible is carried here with the same
  # "Umi_" casing as the other nine. The demo branch used "UMI_" for this one
  # key only. Confirm the live casing in Prism Central and correct if needed —
  # this is the most likely cause of a plan-time failure in this file.
  #
  #   curl -k -H "X-ntnx-api-key: $apiKey" \
  #     "https://prismcentral-emea.atom.ads:9440/api/prism/v4.0/config/categories?%24limit=100"
  #
  # extra_tags values take precedence on key clashes (merge() last-wins);
  # in practice extra_tags should not override mandatory categories.
  vm_categories = merge(
    {
      Umi_BusinessUnit    = var.category_business_unit
      Umi_Environment     = var.category_environment
      Umi_Criticality     = var.category_criticality
      Umi_Recharge        = var.category_recharge
      Umi_PrimaryFunction = var.category_primary_function
      Umi_Application     = var.category_application
      Umi_Description     = var.category_description
      Umi_BUResponsible   = var.category_bu_responsible
      Umi_ITResponsible   = var.category_it_responsible
      Umi_Backup          = var.category_backup
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
