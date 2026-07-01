module "nutanix_vm" {
  for_each = var.module_configs
  source   = "../."

  UMICORE_LOCATION = var.UMICORE_LOCATION
  UMICORE_PROJECT  = var.UMICORE_PROJECT
  environment      = var.environment

  usage_code           = each.value.usage_code
  sequence_number      = each.value.sequence_number
  vm_name_override     = each.value.vm_name_override
  source_type          = each.value.source_type
  template_name        = each.value.template_name
  image_name           = each.value.image_name
  cluster_name         = each.value.cluster_name
  subnet_name          = each.value.subnet_name
  num_vcpus_per_socket = each.value.num_vcpus_per_socket
  num_cpu_sockets      = each.value.num_cpu_sockets
  memory_size_mib      = each.value.memory_size_mib
  os_disk_size_gib     = each.value.os_disk_size_gib
  data_disks           = each.value.data_disks
  os_type              = each.value.os_type
  sysprep_xml          = each.value.sysprep_xml
  cloud_init_userdata  = each.value.cloud_init_userdata
  ad_join              = each.value.ad_join
  ad_join_domain       = each.value.ad_join_domain

  category_business_unit    = each.value.category_business_unit
  category_environment      = each.value.category_environment
  category_criticality      = each.value.category_criticality
  category_recharge         = each.value.category_recharge
  category_primary_function = each.value.category_primary_function
  category_application      = each.value.category_application
  category_description      = each.value.category_description
  category_bu_responsible   = each.value.category_bu_responsible
  category_it_responsible   = each.value.category_it_responsible
  category_backup           = each.value.category_backup
  extra_tags                = each.value.extra_tags
}
