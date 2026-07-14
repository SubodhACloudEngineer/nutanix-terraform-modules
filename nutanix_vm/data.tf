data "nutanix_cluster" "this" {
  name = var.cluster_name
}

data "nutanix_subnet" "this" {
  subnet_name = var.subnet_name
}

# Image Service lookup, image path only.
data "nutanix_image" "this" {
  count = var.source_type == "image" ? 1 : 0

  image_name = var.image_name
}

# VM Template lookup, template path only. v2 API has no singular by-name
# data source, so filter the list endpoint on templateName (OData) and
# index into the single match in nutanix_vm.tf.
data "nutanix_templates_v2" "this" {
  count = var.source_type == "template" ? 1 : 0

  filter = "templateName eq '${var.template_name}'"
}

# Post-template-deployment VM lookup.
# nutanix_virtual_machine is the correct v2.4 data source (nutanix_vm does not exist).
# The vm_uuid output attribute path on nutanix_deploy_templates_v2 must be confirmed
# against the real provider schema; the name below is a placeholder.
# TODO: verify nutanix_deploy_templates_v2.this[0].id (or equivalent) attribute against
# provider v2.4 schema before enabling this data source.
#
# data "nutanix_virtual_machine" "template_deployed" {
#   count  = local.use_template_path ? 1 : 0
#   vm_id  = nutanix_deploy_templates_v2.this[0].id   # placeholder — verify attribute name
#
#   depends_on = [nutanix_deploy_templates_v2.this]
# }
