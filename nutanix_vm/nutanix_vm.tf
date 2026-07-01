# Image path: clone from an Image Service image via the v1 resource.
resource "nutanix_virtual_machine" "this" {
  count = local.use_image_path ? 1 : 0

  name                 = local.vm_name
  cluster_uuid         = data.nutanix_cluster.this.metadata.uuid
  num_vcpus_per_socket = var.num_vcpus_per_socket
  num_sockets          = var.num_cpu_sockets
  memory_size_mib      = var.memory_size_mib

  disk_list {
    data_source_reference = {
      kind = "image"
      uuid = data.nutanix_image.this[0].metadata.uuid
    }

    disk_size_mib = var.os_disk_size_gib != null ? var.os_disk_size_gib * 1024 : null

    device_properties {
      device_type = "DISK"
      disk_address = {
        device_index = 0
        adapter_type = "SCSI"
      }
    }
  }

  dynamic "disk_list" {
    for_each = var.data_disks
    content {
      disk_size_mib = disk_list.value.size_gib * 1024

      device_properties {
        device_type = "DISK"
        disk_address = {
          device_index = disk_list.key + 1
          adapter_type = "SCSI"
        }
      }
    }
  }

  nic_list {
    subnet_uuid = data.nutanix_subnet.this.metadata.uuid
  }

  dynamic "categories" {
    for_each = local.vm_categories
    content {
      name  = categories.key
      value = categories.value
    }
  }

  # Sysprep: provider v2.4 exposes these as flat attributes (parallel to
  # guest_customization_cloud_init_user_data) rather than a nested block.
  guest_customization_sysprep_install_type = local.apply_sysprep ? "PREPARED" : null
  guest_customization_sysprep_unattend_xml = local.apply_sysprep ? base64encode(var.sysprep_xml) : null

  # cloud-init: flat attribute on this resource, not a nested block.
  guest_customization_cloud_init_user_data = local.apply_cloud_init ? base64encode(var.cloud_init_userdata) : null

  lifecycle {
    ignore_changes = [categories]
  }
}

# Template path: deploy from a Prism Central VM Template via the v2 resource.
resource "nutanix_deploy_templates_v2" "this" {
  count = local.use_template_path ? 1 : 0

  ext_id            = data.nutanix_templates_v2.this[0].templates[0].ext_id
  number_of_vms     = 1
  cluster_reference = data.nutanix_cluster.this.metadata.uuid

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
