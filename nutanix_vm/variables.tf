### Location & Project ###

variable "UMICORE_LOCATION" {
  description = <<-EOT
    3-letter Nutanix site code used in the naming convention.
    Allowed values align with the Nutanix site codes in the HLD:
    HOB (Hoboken), WOL (Wollaston), CHU (Chunan), ONS (Olen), RIL (Rilland),
    SNO (Senoko), SRW (Sriracha West), SUC (Suzhou), TNJ (Tianjin),
    CGS (Changshu), JMR (Jiangmen), BUR (Burlington).
    Named UMICORE_LOCATION to match the existing Azure module convention.
  EOT
  type        = string

  validation {
    condition = contains([
      "HOB", "WOL", "CHU", "ONS", "RIL", "SNO",
      "SRW", "SUC", "TNJ", "CGS", "JMR", "BUR",
    ], var.UMICORE_LOCATION)
    error_message = "UMICORE_LOCATION must be one of: HOB, WOL, CHU, ONS, RIL, SNO, SRW, SUC, TNJ, CGS, JMR, BUR."
  }
}

variable "UMICORE_PROJECT" {
  description = "Project name used in category tagging. Matches the project identifier used in the site's Azure DevOps repository name (e.g. NUTANIXDEV)."
  type        = string
}

variable "environment" {
  description = "Deployment environment tier. Drives change management gates and RBAC scope."
  type        = string

  validation {
    condition     = contains(["prd", "tst", "acc", "dev"], var.environment)
    error_message = "The environment variable must be one of: 'prd', 'tst', 'acc', 'dev'."
  }
}

### Naming ###

variable "usage_code" {
  description = "2-letter server role code from the Umicore naming convention (AD cookbook). Known confirmed codes: FS (File Server), WB (Web Server), AS (Application Server). Additional codes to be confirmed from AD cookbook."
  type        = string

  validation {
    condition     = can(regex("^[A-Z]{2}$", var.usage_code))
    error_message = "usage_code must be exactly 2 uppercase letters."
  }
}

variable "sequence_number" {
  description = "4-digit zero-padded sequence number. Determines the sequential identifier for this VM within its site and usage code. Range: 1 to 9999. The engineer is responsible for selecting the next available number — no auto-discovery."
  type        = number

  validation {
    condition     = var.sequence_number >= 1 && var.sequence_number <= 9999
    error_message = "sequence_number must be between 1 and 9999."
  }
}

variable "vm_name_override" {
  description = "Optional. When set, bypasses the dynamic naming convention (UMICORE_LOCATION-usage_code-NNNN) entirely and uses this exact string as the VM name. Use only for acquired sites where legacy hostnames must be preserved. Requires justification in the PR description."
  type        = string
  default     = null
}

### Source Selection ###

variable "source_type" {
  description = <<-EOT
    Determines which Terraform resource and Prism Central API path is used for VM deployment.
    'template' — deploys from a Prism Central VM Template using the nutanix_deploy_templates_v2
      resource (template path). Use for standard Windows Server and RHEL VMs.
    'image'    — clones from an image in the Prism Central Image Service using the
      nutanix_virtual_machine resource (image path). Use for appliances or post-Move migrated VMs.
  EOT
  type        = string

  validation {
    condition     = contains(["template", "image"], var.source_type)
    error_message = "source_type must be one of: 'template', 'image'."
  }
}

variable "template_name" {
  description = "Name of the VM Template in Prism Central Image Service. Required when source_type = 'template'. Must exactly match the template name as it appears in Prism Central."
  type        = string
  default     = null
}

variable "image_name" {
  description = "Name of the image in the Prism Central Image Service. Required when source_type = 'image'. Must exactly match the image name as it appears in Prism Central."
  type        = string
  default     = null
}

### Infrastructure ###

variable "cluster_name" {
  description = "Name of the Nutanix AHV cluster on which to provision the VM. Used to resolve the cluster UUID via a data source lookup against Prism Central. Must exactly match the cluster name in Prism Central."
  type        = string
}

variable "subnet_name" {
  description = "Name of the Nutanix subnet (VLAN) to attach the primary vNIC to. Used to resolve the subnet UUID via a data source lookup against Prism Central."
  type        = string
}

### Compute ###

variable "num_vcpus_per_socket" {
  description = "Number of virtual CPUs per socket. Combined with num_cpu_sockets to give the total vCPU count. No minimum enforced — engineer and approver are responsible for appropriate sizing."
  type        = number
}

variable "num_cpu_sockets" {
  description = "Number of CPU sockets. Most workloads use 1 socket with multiple vCPUs per socket."
  type        = number
  default     = 1
}

variable "memory_size_mib" {
  description = "RAM in mebibytes (MiB). Common values: 4096 (4 GiB), 8192 (8 GiB), 16384 (16 GiB), 32768 (32 GiB)."
  type        = number
}

### Storage ###

variable "os_disk_size_gib" {
  description = "Optional OS disk size override in GiB. When null, the disk size from the source template or image is used as-is."
  type        = number
  default     = null
}

variable "data_disks" {
  description = <<-EOT
    Optional list of additional data disks to attach. Each object requires: size_gib (number)
    and label (string). Empty list = no data disks. Example:
    data_disks = [
      { size_gib = 100, label = "data" },
      { size_gib = 200, label = "logs" }
    ]
  EOT
  type = list(object({
    size_gib = number
    label    = string
  }))
  default  = []
  nullable = false
}

### Guest Customisation ###

variable "os_type" {
  description = <<-EOT
    Operating system type. Determines which guest customisation method is applied at first boot.
    'windows'   — Sysprep via unattend.xml (NGT must be in template)
    'linux'     — cloud-init user-data
    'appliance' — no guest customisation applied
  EOT
  type        = string

  validation {
    condition     = contains(["windows", "linux", "appliance"], var.os_type)
    error_message = "os_type must be one of: 'windows', 'linux', 'appliance'."
  }
}

variable "sysprep_xml" {
  description = "Windows Sysprep unattend.xml content. Required when os_type = 'windows'. Sets hostname, domain join, local admin password at first boot via Nutanix Guest Tools (NGT). SENSITIVE — injected via pipeline variable group from CyberArk/Azure Key Vault, never hardcoded."
  type        = string
  sensitive   = true
  default     = null
}

variable "cloud_init_userdata" {
  description = "cloud-init user-data content. Required when os_type = 'linux'. Handles hostname, SSH key, and domain configuration at first boot."
  type        = string
  sensitive   = true
  default     = null
}

### Active Directory ###

variable "ad_join" {
  description = "Whether the VM should be joined to an Active Directory domain at first boot. For Windows VMs this is handled via Sysprep unattend.xml. For Linux via cloud-init."
  type        = bool
  default     = true
  nullable    = false
}

variable "ad_join_domain" {
  description = "Active Directory domain to join. Umicore domains: 'atom.ads' (forest root), 'nucleus.atom.ads' (child domain)."
  type        = string
  default     = "nucleus.atom.ads"
  nullable    = false
}

### Mandatory Categories (all 10 required) ###

variable "category_business_unit" {
  description = "Nutanix category BusinessUnit. Identifies the Umicore business unit owning this workload. Used for RBAC scope and cost reporting. Example: Manufacturing, IT, Finance, R&D."
  type        = string
}

variable "category_environment" {
  description = "Nutanix category Environment. Must match the 'environment' variable value. Drives change management gates and RBAC scope."
  type        = string

  validation {
    condition     = contains(["prd", "tst", "acc", "dev"], var.category_environment)
    error_message = "category_environment must be one of: 'prd', 'tst', 'acc', 'dev'."
  }
}

variable "category_criticality" {
  description = "Nutanix category Criticality. Defines workload importance. Drives incident priority and DR tier assignment."
  type        = string

  validation {
    condition     = contains(["Critical", "High", "Medium", "Low"], var.category_criticality)
    error_message = "category_criticality must be one of: 'Critical', 'High', 'Medium', 'Low'."
  }
}

variable "category_recharge" {
  description = "Nutanix category Recharge. Cost allocation code for financial chargeback. Example: CC-MFG-001, CC-IT-OPS."
  type        = string
}

variable "category_primary_function" {
  description = "Nutanix category PrimaryFunction. Primary application function of this VM. Drives LogicMonitor monitoring templates. Example: ApplicationServer, Database, Monitoring, WebServer."
  type        = string
}

variable "category_application" {
  description = "Nutanix category Application. Name of the application hosted on this VM. Used for CMDB population and inventory. Example: SAP-Middleware, SCCM, IIS, LogicMonitor."
  type        = string
}

variable "category_description" {
  description = "Nutanix category Description. Brief contextual details about this workload. Example: SAP middleware tier for HOB plant systems."
  type        = string
}

variable "category_bu_responsible" {
  description = "Nutanix category BUResponsible. Business contact / owner email address. Used for incident notification and ownership tracking. Example: john.doe@umicore.com."
  type        = string
}

variable "category_it_responsible" {
  description = "Nutanix category ITResponsible. Technical contact / owner email address. Used for incident response and change management. Example: infra-team@umicore.com."
  type        = string
}

variable "category_backup" {
  description = <<-EOT
    Nutanix category Backup. CRITICAL — drives Veeam VBR 13 backup job tier assignment
    automatically. Veeam queries Prism Central for VMs by this category value.
    Gold   = daily backup + offsite copy
    Silver = daily backup
    Bronze = weekly backup
    None   = excluded from backup (requires explicit justification)
  EOT
  type        = string

  validation {
    condition     = contains(["Gold", "Silver", "Bronze", "None"], var.category_backup)
    error_message = "category_backup must be one of: 'Gold', 'Silver', 'Bronze', 'None'. This drives Veeam VBR 13 job assignment."
  }
}

### Extra Tags ###

variable "extra_tags" {
  description = "Additional Nutanix categories to apply beyond the 10 mandatory categories. Map of category name to value."
  type        = map(string)
  default     = {}
  nullable    = false
}
