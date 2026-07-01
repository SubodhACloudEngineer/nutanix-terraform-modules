# unit_nutanix_vm.tftest.hcl
#
# Integration tests for the nutanix_vm module.
# These tests use command = plan against a REAL Nutanix Prism Central cluster.
# They are NOT run by the CI pipeline (which only runs the mock provider tests).
# Run these manually against the HOB pilot cluster with valid credentials:
#
#   cd nutanix_vm/unit
#   terraform test -filter=tests/unit_nutanix_vm.tftest.hcl \
#     -var-file=variables.tfvars \
#     -var="nutanix_username=<user>" \
#     -var="nutanix_password=<pass>" \
#     -var="nutanix_endpoint=<prism-central-ip>"
#
# What they test:
#   - VM naming convention (dynamic and override)
#   - Variable validation rules (backup, environment categories)
#   - All 10 mandatory categories are applied

# ── Shared provider variables ──────────────────────────────────────────────
variables {
  UMICORE_LOCATION = "HOB"
  UMICORE_PROJECT  = "NUTANIXDEV"
  environment      = "tst"
  nutanix_username = "placeholder"
  nutanix_password = "placeholder"
  nutanix_endpoint = "127.0.0.1"
  nutanix_insecure = true
}


# ════════════════════════════════════════════════════════════════════════════════
# NAMING TESTS
# ════════════════════════════════════════════════════════════════════════════════

run "naming_convention_dynamic" {
  command = plan

  variables {
    module_configs = {
      test = {
        usage_code                = "AS"
        sequence_number           = 9001
        source_type               = "image"
        image_name                = "WIN2025-golden-v1.0"
        cluster_name              = "HOB-NTX-CL01"
        subnet_name               = "VLAN-APP-100"
        num_vcpus_per_socket      = 2
        memory_size_mib           = 4096
        os_type                   = "windows"
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "Low"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "ApplicationServer"
        category_application      = "UnitTest"
        category_description      = "naming convention test"
        category_bu_responsible   = "infra-test@umicore.com"
        category_it_responsible   = "infra-team@umicore.com"
        category_backup           = "None"
      }
    }
  }

  # VM name: HOB + AS + 9001 → "hob-as-9001"
  assert {
    condition     = module.nutanix_vm["test"].vm_name_local == "hob-as-9001"
    error_message = "Expected hob-as-9001, got ${module.nutanix_vm["test"].vm_name_local}"
  }

  assert {
    condition     = module.nutanix_vm["test"].umicore_location == "HOB"
    error_message = "Expected umicore_location HOB, got ${module.nutanix_vm["test"].umicore_location}"
  }
}


run "naming_convention_override" {
  command = plan

  variables {
    module_configs = {
      test = {
        usage_code                = "AS"
        sequence_number           = 1
        vm_name_override          = "LEGACY-ACQ-SERVER-01"
        source_type               = "image"
        image_name                = "WIN2025-golden-v1.0"
        cluster_name              = "HOB-NTX-CL01"
        subnet_name               = "VLAN-APP-100"
        num_vcpus_per_socket      = 2
        memory_size_mib           = 4096
        os_type                   = "windows"
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "Low"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "ApplicationServer"
        category_application      = "LegacyApp"
        category_description      = "Acquired site legacy server"
        category_bu_responsible   = "infra-test@umicore.com"
        category_it_responsible   = "infra-team@umicore.com"
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


# ════════════════════════════════════════════════════════════════════════════════
# VALIDATION FAILURE TESTS
# These tests assert that invalid inputs are REJECTED by the module.
# Variable validation fires before provider calls — no cluster needed.
# ════════════════════════════════════════════════════════════════════════════════

run "category_backup_validation" {
  command         = plan
  expect_failures = [var.module_configs]

  variables {
    module_configs = {
      test = {
        usage_code                = "AS"
        sequence_number           = 1
        source_type               = "image"
        image_name                = "WIN2025-golden-v1.0"
        cluster_name              = "HOB-NTX-CL01"
        subnet_name               = "VLAN-APP-100"
        num_vcpus_per_socket      = 2
        memory_size_mib           = 4096
        os_type                   = "windows"
        category_business_unit    = "IT"
        category_environment      = "tst"
        category_criticality      = "Low"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "ApplicationServer"
        category_application      = "UnitTest"
        category_description      = "backup validation test"
        category_bu_responsible   = "infra-test@umicore.com"
        category_it_responsible   = "infra-team@umicore.com"
        category_backup           = "Weekly" # INVALID — not in Gold/Silver/Bronze/None
      }
    }
  }
}


run "category_environment_validation" {
  command         = plan
  expect_failures = [var.module_configs]

  variables {
    module_configs = {
      test = {
        usage_code                = "AS"
        sequence_number           = 1
        source_type               = "image"
        image_name                = "WIN2025-golden-v1.0"
        cluster_name              = "HOB-NTX-CL01"
        subnet_name               = "VLAN-APP-100"
        num_vcpus_per_socket      = 2
        memory_size_mib           = 4096
        os_type                   = "windows"
        category_business_unit    = "IT"
        category_environment      = "prod" # INVALID — must be prd/tst/acc/dev
        category_criticality      = "Low"
        category_recharge         = "CC-IT-TST"
        category_primary_function = "ApplicationServer"
        category_application      = "UnitTest"
        category_description      = "environment validation test"
        category_bu_responsible   = "infra-test@umicore.com"
        category_it_responsible   = "infra-team@umicore.com"
        category_backup           = "None"
      }
    }
  }
}


# ════════════════════════════════════════════════════════════════════════════════
# CATEGORY TESTS
# ════════════════════════════════════════════════════════════════════════════════

run "mandatory_categories_applied" {
  command = plan

  variables {
    module_configs = {
      test = {
        usage_code                = "FS"
        sequence_number           = 1
        source_type               = "template"
        template_name             = "WIN2025-golden-v1.0"
        cluster_name              = "HOB-NTX-CL01"
        subnet_name               = "VLAN-APP-100"
        num_vcpus_per_socket      = 2
        memory_size_mib           = 4096
        os_type                   = "windows"
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

  assert {
    condition     = length(keys(module.nutanix_vm["test"].categories_applied)) == 10
    error_message = "Expected 10 mandatory categories, got ${length(keys(module.nutanix_vm["test"].categories_applied))}"
  }

  assert {
    condition     = module.nutanix_vm["test"].categories_applied["Backup"] == "Gold"
    error_message = "Backup category should be Gold"
  }

  assert {
    condition     = module.nutanix_vm["test"].categories_applied["Environment"] == "prd"
    error_message = "Environment category should be prd"
  }
}
