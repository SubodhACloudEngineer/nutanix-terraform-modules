variable "UMICORE_LOCATION" {
  type = string
  validation {
    condition = contains([
      "HOB", "WOL", "CHU", "ONS", "RIL", "SNO",
      "SRW", "SUC", "TNJ", "CGS", "JMR", "BUR",
    ], var.UMICORE_LOCATION)
    error_message = "UMICORE_LOCATION must be one of: HOB, WOL, CHU, ONS, RIL, SNO, SRW, SUC, TNJ, CGS, JMR, BUR."
  }
}

variable "UMICORE_PROJECT" {
  type = string
}

variable "environment" {
  type = string
}

variable "nutanix_username" {
  type      = string
  sensitive = true
}

variable "nutanix_password" {
  type      = string
  sensitive = true
}

variable "nutanix_endpoint" {
  type = string
}

variable "nutanix_insecure" {
  type    = bool
  default = false
}

variable "module_configs" {
  type = map(object({
    usage_code           = string
    sequence_number      = number
    vm_name_override     = optional(string, null)
    source_type          = string
    template_name        = optional(string, null)
    image_name           = optional(string, null)
    cluster_name         = string
    subnet_name          = string
    num_vcpus_per_socket = number
    num_cpu_sockets      = optional(number, 1)
    memory_size_mib      = number
    os_disk_size_gib     = optional(number, null)
    data_disks = optional(list(object({
      size_gib = number
      label    = string
    })), [])
    os_type             = string
    sysprep_xml         = optional(string, null)
    cloud_init_userdata = optional(string, null)
    ad_join             = optional(bool, true)
    ad_join_domain      = optional(string, "nucleus.atom.ads")

    category_business_unit    = string
    category_environment      = string
    category_criticality      = string
    category_recharge         = string
    category_primary_function = string
    category_application      = string
    category_description      = string
    category_bu_responsible   = string
    category_it_responsible   = string
    category_backup           = string
    extra_tags                = optional(map(string), {})
  }))

  validation {
    condition = alltrue([
      for k, v in var.module_configs :
      contains(["Gold", "Silver", "Bronze", "None"], v.category_backup)
    ])
    error_message = "category_backup must be one of: Gold, Silver, Bronze, None."
  }

  validation {
    condition = alltrue([
      for k, v in var.module_configs :
      contains(["prd", "tst", "acc", "dev"], v.category_environment)
    ])
    error_message = "category_environment must be one of: prd, tst, acc, dev."
  }

  validation {
    condition = alltrue([
      for k, v in var.module_configs :
      contains(["template", "image"], v.source_type)
    ])
    error_message = "source_type must be one of: template, image."
  }

  validation {
    condition = alltrue([
      for k, v in var.module_configs :
      contains(["Critical", "High", "Medium", "Low"], v.category_criticality)
    ])
    error_message = "category_criticality must be one of: Critical, High, Medium, Low."
  }
}
