# unit_nutanix_vm_mock.tftest.hcl
#
# These tests use Terraform's mock_provider feature (available since Terraform 1.7).
# They run ENTIRELY LOCALLY with no Nutanix cluster, no credentials, and no
# network calls to Prism Central.
#
# What they test:
#   - VM naming logic (dynamic convention and override)
#   - Sub-resource naming (osdisk, nic, datadisk labels)
#   - All variable validation rules (environment, backup, source_type, etc.)
#   - Category mapping (all 10 mandatory categories)
#   - Conditional resource selection (template vs image path)
#   - Output values are computable
#
# What they do NOT test (needs a real cluster — Sprint 4):
#   - Whether the Prism Central API accepts the request
#   - Whether the VM is actually created on AHV
#   - Whether NGT/Sysprep runs correctly on first boot

mock_provider "nutanix" {
  mock_data "nutanix_cluster" {
    defaults = {
      id   = "mock-cluster-uuid-01"
      name = "HOB-NTX-CL01"
    }
  }
  mock_data "nutanix_subnet" {
    defaults = {
      id   = "mock-subnet-uuid-01"
      name = "VLAN-APP-100"
    }
  }
  # Used by image path (source_type = "image")
  mock_data "nutanix_image" {
    defaults = {
      id   = "mock-image-uuid-01"
      name = "WIN2025-golden-v1.0"
    }
  }
  # Used by template path (source_type = "template")
  mock_data "nutanix_template_v2" {
    defaults = {
      id     = "mock-template-uuid-01"
      ext_id = "mock-template-ext-id-01"
      name   = "WIN2025-template-v1.0"
    }
  }
}

# ── Shared variables used across most tests ──────────────────────────────────
variables {
  UMICORE_LOCATION = "HOB"
  UMICORE_PROJECT  = "NUTANIXDEV"
  environment      = "tst"
  # nutanix_* provider vars — ignored by mock, but required by unit/provider.tf
  nutanix_username = "mock-user"
  nutanix_password = "mock-pass"
  nutanix_endpoint = "10.0.0.1"
  nutanix_insecure = true
}


# ════════════════════════════════════════════════════════════════════════════════
# NAMING TESTS
# ════════════════════════════════════════════════════════════════════════════════

run "naming_dynamic_application_server" {
  command = plan

  variables {
    module_configs = {
      test = {
        usage_code             = "AS"
        sequence_number        = 13
        source_type            = "image"
        image_name             = "WIN2025-golden-v1.0"
        cluster_name           = "HOB-NTX-CL01"
        subnet_name            = "VLAN-APP-100"
        num_vcpus_per_socket   = 2
        memory_size_mib        = 4096
        os_type                = "windows"
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "Low"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "ApplicationServer"
        category_application      = "UnitTest"
        category_description      = "naming test"
        category_bu_responsible   = "test@umicore.com"
        category_it_responsible   = "infra@umicore.com"
        category_backup           = "None"
      }
    }
  }

  # VM name: HOB + AS + 0013 → "hob-as-0013"
  assert {
    condition     = module.nutanix_vm["test"].vm_name_local == "hob-as-0013"
    error_message = "Expected hob-as-0013, got ${module.nutanix_vm["test"].vm_name_local}"
  }

  # OS disk label
  assert {
    condition     = module.nutanix_vm["test"].os_disk_label == "hob-as-0013-osdisk"
    error_message = "Expected hob-as-0013-osdisk, got ${module.nutanix_vm["test"].os_disk_label}"
  }

  # NIC label
  assert {
    condition     = module.nutanix_vm["test"].nic_name_local == "hob-as-0013-nic"
    error_message = "Expected hob-as-0013-nic, got ${module.nutanix_vm["test"].nic_name_local}"
  }
}


run "naming_dynamic_file_server_zero_padding" {
  command = plan

  variables {
    module_configs = {
      test = {
        usage_code             = "FS"
        sequence_number        = 1
        source_type            = "image"
        image_name             = "WIN2025-golden-v1.0"
        cluster_name           = "HOB-NTX-CL01"
        subnet_name            = "VLAN-APP-100"
        num_vcpus_per_socket   = 1
        memory_size_mib        = 2048
        os_type                = "windows"
        category_business_unit    = "Manufacturing"
        category_environment      = "tst"
        category_criticality      = "Low"
        category_recharge         = "CC-MFG-001"
        category_primary_function = "FileServer"
        category_application      = "SharedStorage"
        category_description      = "zero padding test"
        category_bu_responsible   = "test@umicore.com"
        category_it_responsible   = "infra@umicore.com"
        category_backup           = "Gold"
      }
    }
  }

  # Sequence 1 must zero-pad to 4 digits → "hob-fs-0001"
  assert {
    condition     = module.nutanix_vm["test"].vm_name_local == "hob-fs-0001"
    error_message = "Expected hob-fs-0001 (zero padded), got ${module.nutanix_vm["test"].vm_name_local}"
  }
}


run "naming_override_bypasses_convention" {
  command = plan

  variables {
    module_configs = {
      test = {
        usage_code             = "AS"
        sequence_number        = 1
        vm_name_override       = "LEGACY-ACQ-SERVER-01"
        source_type            = "image"
        image_name             = "WIN2025-golden-v1.0"
        cluster_name           = "HOB-NTX-CL01"
        subnet_name            = "VLAN-APP-100"
        num_vcpus_per_socket   = 1
        memory_size_mib        = 2048
        os_type                = "appliance"
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "Low"
        category_recharge         = "CC-IT-ACQ"
        category_primary_function = "ApplicationServer"
        category_application      = "LegacyApp"
        category_description      = "Acquired site legacy server"
        category_bu_responsible   = "test@umicore.com"
        category_it_responsible   = "infra@umicore.com"
        category_backup           = "Silver"
      }
    }
  }

  # Override must be used verbatim — no lowercasing, no SITE-CODE prefix
  assert {
    condition     = module.nutanix_vm["test"].vm_name_local == "LEGACY-ACQ-SERVER-01"
    error_message = "Override was not used verbatim. Got: ${module.nutanix_vm["test"].vm_name_local}"
  }
}


run "naming_different_site_chu" {
  command = plan

  variables {
    UMICORE_LOCATION = "CHU"
    module_configs = {
      test = {
        usage_code             = "WB"
        sequence_number        = 42
        source_type            = "image"
        image_name             = "WIN2022-golden-v1.0"
        cluster_name           = "CHU-NTX-CL01"
        subnet_name            = "VLAN-WEB-200"
        num_vcpus_per_socket   = 4
        memory_size_mib        = 8192
        os_type                = "windows"
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "Medium"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "WebServer"
        category_application      = "IIS"
        category_description      = "Web server Chunan"
        category_bu_responsible   = "test@umicore.com"
        category_it_responsible   = "infra@umicore.com"
        category_backup           = "Silver"
      }
    }
  }

  assert {
    condition     = module.nutanix_vm["test"].vm_name_local == "chu-wb-0042"
    error_message = "Expected chu-wb-0042, got ${module.nutanix_vm["test"].vm_name_local}"
  }
}


# ════════════════════════════════════════════════════════════════════════════════
# DATA DISK LABEL TESTS
# ════════════════════════════════════════════════════════════════════════════════

run "data_disk_labels_two_disks" {
  command = plan

  variables {
    module_configs = {
      test = {
        usage_code             = "DB"
        sequence_number        = 5
        source_type            = "image"
        image_name             = "RHEL9-golden-v1.0"
        cluster_name           = "HOB-NTX-CL01"
        subnet_name            = "VLAN-APP-100"
        num_vcpus_per_socket   = 4
        memory_size_mib        = 16384
        os_type                = "linux"
        data_disks = [
          { size_gib = 200, label = "data" },
          { size_gib = 100, label = "logs" }
        ]
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "High"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "Database"
        category_application      = "PostgreSQL"
        category_description      = "DB disk label test"
        category_bu_responsible   = "test@umicore.com"
        category_it_responsible   = "infra@umicore.com"
        category_backup           = "Gold"
      }
    }
  }

  assert {
    condition     = module.nutanix_vm["test"].data_disk_labels[0] == "hob-db-0005-datadisk-01"
    error_message = "First data disk label incorrect: ${module.nutanix_vm["test"].data_disk_labels[0]}"
  }

  assert {
    condition     = module.nutanix_vm["test"].data_disk_labels[1] == "hob-db-0005-datadisk-02"
    error_message = "Second data disk label incorrect: ${module.nutanix_vm["test"].data_disk_labels[1]}"
  }

  assert {
    condition     = length(module.nutanix_vm["test"].data_disk_labels) == 2
    error_message = "Expected 2 data disk labels, got ${length(module.nutanix_vm["test"].data_disk_labels)}"
  }
}


run "no_data_disks_empty_labels" {
  command = plan

  variables {
    module_configs = {
      test = {
        usage_code             = "AS"
        sequence_number        = 7
        source_type            = "image"
        image_name             = "WIN2025-golden-v1.0"
        cluster_name           = "HOB-NTX-CL01"
        subnet_name            = "VLAN-APP-100"
        num_vcpus_per_socket   = 2
        memory_size_mib        = 4096
        os_type                = "windows"
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "Low"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "ApplicationServer"
        category_application      = "TestApp"
        category_description      = "no disks test"
        category_bu_responsible   = "test@umicore.com"
        category_it_responsible   = "infra@umicore.com"
        category_backup           = "None"
      }
    }
  }

  assert {
    condition     = length(module.nutanix_vm["test"].data_disk_labels) == 0
    error_message = "Expected empty data disk list when no data_disks specified"
  }
}


# ════════════════════════════════════════════════════════════════════════════════
# CATEGORY TESTS
# ════════════════════════════════════════════════════════════════════════════════

run "all_10_mandatory_categories_present" {
  command = plan

  variables {
    module_configs = {
      test = {
        usage_code             = "FS"
        sequence_number        = 1
        source_type            = "template"
        template_name          = "WIN2025-template-v1.0"
        cluster_name           = "HOB-NTX-CL01"
        subnet_name            = "VLAN-APP-100"
        num_vcpus_per_socket   = 2
        memory_size_mib        = 4096
        os_type                = "windows"
        category_business_unit    = "Manufacturing"
        category_environment      = "prd"
        category_criticality      = "High"
        category_recharge         = "CC-MFG-001"
        category_primary_function = "FileServer"
        category_application      = "SharedStorage"
        category_description      = "HOB plant file share"
        category_bu_responsible   = "plant-owner@umicore.com"
        category_it_responsible   = "infra-team@umicore.com"
        category_backup           = "Gold"
      }
    }
  }

  # There must be exactly 10 mandatory categories (no extras in this test)
  assert {
    condition     = length(keys(module.nutanix_vm["test"].categories_applied)) == 10
    error_message = "Expected 10 categories, got ${length(keys(module.nutanix_vm["test"].categories_applied))}"
  }

  assert {
    condition     = module.nutanix_vm["test"].categories_applied["Backup"] == "Gold"
    error_message = "Backup category should be Gold"
  }

  assert {
    condition     = module.nutanix_vm["test"].categories_applied["Environment"] == "prd"
    error_message = "Environment category should be prd"
  }

  assert {
    condition     = module.nutanix_vm["test"].categories_applied["BusinessUnit"] == "Manufacturing"
    error_message = "BusinessUnit category incorrect"
  }

  assert {
    condition     = module.nutanix_vm["test"].categories_applied["Criticality"] == "High"
    error_message = "Criticality category incorrect"
  }
}


run "extra_tags_merge_with_mandatory" {
  command = plan

  variables {
    module_configs = {
      test = {
        usage_code             = "AS"
        sequence_number        = 1
        source_type            = "image"
        image_name             = "WIN2025-golden-v1.0"
        cluster_name           = "HOB-NTX-CL01"
        subnet_name            = "VLAN-APP-100"
        num_vcpus_per_socket   = 2
        memory_size_mib        = 4096
        os_type                = "windows"
        extra_tags             = { "NamingException" = "false", "MigrationWave" = "Wave1" }
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "Low"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "ApplicationServer"
        category_application      = "UnitTest"
        category_description      = "extra tags test"
        category_bu_responsible   = "test@umicore.com"
        category_it_responsible   = "infra@umicore.com"
        category_backup           = "None"
      }
    }
  }

  # 10 mandatory + 2 extra = 12 total
  assert {
    condition     = length(keys(module.nutanix_vm["test"].categories_applied)) == 12
    error_message = "Expected 12 categories (10 mandatory + 2 extra), got ${length(keys(module.nutanix_vm["test"].categories_applied))}"
  }

  assert {
    condition     = module.nutanix_vm["test"].categories_applied["NamingException"] == "false"
    error_message = "NamingException extra tag not found in categories_applied"
  }

  assert {
    condition     = module.nutanix_vm["test"].categories_applied["MigrationWave"] == "Wave1"
    error_message = "MigrationWave extra tag not found in categories_applied"
  }
}


# ════════════════════════════════════════════════════════════════════════════════
# SOURCE TYPE TESTS
# ════════════════════════════════════════════════════════════════════════════════

run "source_type_image_path_selected" {
  command = plan

  variables {
    module_configs = {
      test = {
        usage_code             = "AS"
        sequence_number        = 1
        source_type            = "image"
        image_name             = "WIN2025-golden-v1.0"
        cluster_name           = "HOB-NTX-CL01"
        subnet_name            = "VLAN-APP-100"
        num_vcpus_per_socket   = 2
        memory_size_mib        = 4096
        os_type                = "windows"
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "Low"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "ApplicationServer"
        category_application      = "UnitTest"
        category_description      = "source type test"
        category_bu_responsible   = "test@umicore.com"
        category_it_responsible   = "infra@umicore.com"
        category_backup           = "None"
      }
    }
  }

  assert {
    condition     = module.nutanix_vm["test"].source_type_local == "image"
    error_message = "source_type should be image"
  }

  assert {
    condition     = module.nutanix_vm["test"].source_type_used == "image"
    error_message = "source_type_used output should be image"
  }
}


run "source_type_template_path_selected" {
  command = plan

  variables {
    module_configs = {
      test = {
        usage_code             = "AS"
        sequence_number        = 1
        source_type            = "template"
        template_name          = "WIN2025-template-v1.0"
        cluster_name           = "HOB-NTX-CL01"
        subnet_name            = "VLAN-APP-100"
        num_vcpus_per_socket   = 2
        memory_size_mib        = 4096
        os_type                = "windows"
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "Low"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "ApplicationServer"
        category_application      = "UnitTest"
        category_description      = "template source type test"
        category_bu_responsible   = "test@umicore.com"
        category_it_responsible   = "infra@umicore.com"
        category_backup           = "None"
      }
    }
  }

  assert {
    condition     = module.nutanix_vm["test"].source_type_local == "template"
    error_message = "source_type should be template"
  }
}


# ════════════════════════════════════════════════════════════════════════════════
# VALIDATION FAILURE TESTS
# These tests assert that invalid inputs are REJECTED by the module.
# ════════════════════════════════════════════════════════════════════════════════

run "invalid_backup_value_rejected" {
  command = plan
  expect_failures = [var.module_configs]

  variables {
    module_configs = {
      test = {
        usage_code             = "AS"
        sequence_number        = 1
        source_type            = "image"
        image_name             = "WIN2025-golden-v1.0"
        cluster_name           = "HOB-NTX-CL01"
        subnet_name            = "VLAN-APP-100"
        num_vcpus_per_socket   = 2
        memory_size_mib        = 4096
        os_type                = "windows"
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "Low"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "ApplicationServer"
        category_application      = "UnitTest"
        category_description      = "validation test"
        category_bu_responsible   = "test@umicore.com"
        category_it_responsible   = "infra@umicore.com"
        category_backup           = "Daily"  # INVALID — not in Gold/Silver/Bronze/None
      }
    }
  }
}


run "invalid_environment_value_rejected" {
  command = plan
  expect_failures = [var.module_configs]

  variables {
    module_configs = {
      test = {
        usage_code             = "AS"
        sequence_number        = 1
        source_type            = "image"
        image_name             = "WIN2025-golden-v1.0"
        cluster_name           = "HOB-NTX-CL01"
        subnet_name            = "VLAN-APP-100"
        num_vcpus_per_socket   = 2
        memory_size_mib        = 4096
        os_type                = "windows"
        category_business_unit    = "IT"
        category_environment      = "staging"  # INVALID — not in prd/tst/acc/dev
        category_criticality      = "Low"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "ApplicationServer"
        category_application      = "UnitTest"
        category_description      = "validation test"
        category_bu_responsible   = "test@umicore.com"
        category_it_responsible   = "infra@umicore.com"
        category_backup           = "None"
      }
    }
  }
}


run "invalid_source_type_rejected" {
  command = plan
  expect_failures = [var.module_configs]

  variables {
    module_configs = {
      test = {
        usage_code             = "AS"
        sequence_number        = 1
        source_type            = "marketplace"  # INVALID — removed from v0.3 design
        image_name             = "WIN2025-golden-v1.0"
        cluster_name           = "HOB-NTX-CL01"
        subnet_name            = "VLAN-APP-100"
        num_vcpus_per_socket   = 2
        memory_size_mib        = 4096
        os_type                = "windows"
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "Low"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "ApplicationServer"
        category_application      = "UnitTest"
        category_description      = "source type validation test"
        category_bu_responsible   = "test@umicore.com"
        category_it_responsible   = "infra@umicore.com"
        category_backup           = "None"
      }
    }
  }
}


run "invalid_umicore_location_rejected" {
  command = plan
  expect_failures = [module.nutanix_vm]

  variables {
    UMICORE_LOCATION = "NYC"  # INVALID — not in the allowed 12 site codes
    module_configs = {
      test = {
        usage_code             = "AS"
        sequence_number        = 1
        source_type            = "image"
        image_name             = "WIN2025-golden-v1.0"
        cluster_name           = "HOB-NTX-CL01"
        subnet_name            = "VLAN-APP-100"
        num_vcpus_per_socket   = 2
        memory_size_mib        = 4096
        os_type                = "windows"
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "Low"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "ApplicationServer"
        category_application      = "UnitTest"
        category_description      = "location validation test"
        category_bu_responsible   = "test@umicore.com"
        category_it_responsible   = "infra@umicore.com"
        category_backup           = "None"
      }
    }
  }
}


run "invalid_criticality_value_rejected" {
  command = plan
  expect_failures = [var.module_configs]

  variables {
    module_configs = {
      test = {
        usage_code             = "AS"
        sequence_number        = 1
        source_type            = "image"
        image_name             = "WIN2025-golden-v1.0"
        cluster_name           = "HOB-NTX-CL01"
        subnet_name            = "VLAN-APP-100"
        num_vcpus_per_socket   = 2
        memory_size_mib        = 4096
        os_type                = "windows"
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "P1"  # INVALID — must be Critical/High/Medium/Low
        category_recharge         = "CC-IT-TST"
        category_primary_function = "ApplicationServer"
        category_application      = "UnitTest"
        category_description      = "criticality validation test"
        category_bu_responsible   = "test@umicore.com"
        category_it_responsible   = "infra@umicore.com"
        category_backup           = "None"
      }
    }
  }
}
