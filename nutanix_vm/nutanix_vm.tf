# Image path: clone from an Image Service image via the v4 (v2 resource) API.
resource "nutanix_virtual_machine_v2" "this" {
  count = local.use_image_path ? 1 : 0

  name                 = local.vm_name
  num_sockets          = var.num_cpu_sockets
  num_cores_per_socket = var.num_vcpus_per_socket
  memory_size_bytes    = var.memory_size_mib * 1024 * 1024

  cluster {
    ext_id = data.nutanix_clusters_v2.this.cluster_entities[0].ext_id
  }

  boot_config {
    legacy_boot {
      boot_order = var.boot_device_order_list
    }
  }

  # OS disk, cloned from the Image Service image.
  disks {
    disk_address {
      bus_type = "SCSI"
      index    = 0
    }
    backing_info {
      vm_disk {
        data_source {
          reference {
            image_reference {
              image_ext_id = data.nutanix_images_v2.this[0].images[0].ext_id
            }
          }
        }
        # disk_size_bytes overrides the source image disk size when set.
        disk_size_bytes = var.os_disk_size_gib != null ? var.os_disk_size_gib * 1024 * 1024 * 1024 : null
      }
    }
  }

  # Additional data disks, blank-provisioned on the SCSI bus after the OS disk.
  dynamic "disks" {
    for_each = var.data_disks
    content {
      disk_address {
        bus_type = "SCSI"
        index    = disks.key + 1
      }
      backing_info {
        vm_disk {
          disk_size_bytes = disks.value.size_gib * 1024 * 1024 * 1024
        }
      }
    }
  }

  nics {
    nic_network_info {
      virtual_ethernet_nic_network_info {
        nic_type  = "NORMAL_NIC"
        vlan_mode = "ACCESS"
        subnet {
          ext_id = data.nutanix_subnets_v2.this.subnets[0].ext_id
        }
      }
    }
  }

  # v4 applies categories by ext_id (UUID). local.vm_categories is the
  # name/value map; the ext_ids are resolved in data.tf via
  # nutanix_categories_v2 keyed by the same category name.
  dynamic "categories" {
    for_each = local.vm_categories
    content {
      ext_id = data.nutanix_categories_v2.this[categories.key].categories[0].ext_id
    }
  }

  # cloud-init guest customisation (linux). Sysprep for the image path is not
  # wired here — Windows guest customisation remains a template-path feature.
  dynamic "guest_customization" {
    for_each = local.apply_cloud_init ? [1] : []
    content {
      config {
        cloud_init {
          cloud_init_script {
            user_data {
              value = base64encode(var.cloud_init_userdata)
            }
          }
        }
      }
    }
  }

  # NOTE: lifecycle.ignore_changes = [categories] was previously set here and
  # has been REMOVED. It suppressed all post-creation category drift, which
  # meant a change to Umi_Backup in tfvars would never reach Prism Central and
  # the VM would silently stay on its original Veeam tier forever. Categories
  # must be manageable after creation.
  #
  # If a permanent diff appears on the categories block after the first real
  # apply, that is an ordering problem to diagnose (the provider may return
  # categories in a different order than declared) — not something to suppress.
  # Raise it rather than reinstating this block.
}

# Template path: deploy from a Prism Central VM Template via the v2 resource.
resource "nutanix_deploy_templates_v2" "this" {
  count = local.use_template_path ? 1 : 0

  ext_id            = data.nutanix_templates_v2.this[0].templates[0].ext_id
  number_of_vms     = 1
  cluster_reference = data.nutanix_clusters_v2.this.cluster_entities[0].ext_id

  override_vm_config_map {
    name                 = local.vm_name
    num_sockets          = var.num_cpu_sockets
    num_cores_per_socket = var.num_vcpus_per_socket
    memory_size_bytes    = var.memory_size_mib * 1024 * 1024

    dynamic "guest_customization" {
      for_each = local.apply_sysprep || local.apply_cloud_init ? [1] : []
      content {
        config {
          dynamic "sysprep" {
            for_each = local.apply_sysprep ? [1] : []
            content {
              install_type = "PREPARED"
              sysprep_script {
                unattend_xml {
                  value = base64encode(var.sysprep_xml)
                }
              }
            }
          }

          dynamic "cloud_init" {
            for_each = local.apply_cloud_init ? [1] : []
            content {
              cloud_init_script {
                user_data {
                  value = base64encode(var.cloud_init_userdata)
                }
              }
            }
          }
        }
      }
    }
  }

  # nutanix_deploy_templates_v2 / override_vm_config_map expose no
  # categories argument in provider v2.4 — local.vm_categories cannot be
  # applied here. No lifecycle.ignore_changes block either, since
  # Terraform rejects ignore_changes entries that name a non-existent
  # attribute.
}

# KNOWN LIMITATION: nutanix_deploy_templates_v2 in provider v2.4 does not
# support applying Nutanix categories during deployment via
# override_vm_config_map. This is a critical gap because the Backup category
# drives Veeam VBR 13 job assignment automatically.
#
# The image path above now applies categories natively via
# nutanix_virtual_machine_v2 (categories { ext_id }). The template path still
# needs an out-of-band step. Recommended remediation paths (choose one):
#   A) Import the template-deployed VM into state as a
#      nutanix_virtual_machine_v2 resource and manage its categories:
#        terraform import 'module.<key>.nutanix_virtual_machine_v2.categories_post_deploy[0]' <vm_uuid>
#   B) Apply categories via the Prism Central v4 API in a post-deployment
#      pipeline step (PATCH the VM with the resolved category ext_ids).
#   C) Wait for a future provider version where nutanix_deploy_templates_v2
#      override_vm_config_map exposes a categories block.
