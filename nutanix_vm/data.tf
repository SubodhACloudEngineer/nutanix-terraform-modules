# Cluster lookup. v4 exposes only a plural list data source, so filter the
# list endpoint on name (OData) and index into the single match. Used by both
# the image path (nutanix_virtual_machine_v2) and the template path
# (nutanix_deploy_templates_v2 cluster_reference).
data "nutanix_clusters_v2" "this" {
  filter = "name eq '${var.cluster_name}'"
}

# Subnet lookup, image path only in practice. v4 exposes only a plural list
# data source; filter on name and index into the single match.
data "nutanix_subnets_v2" "this" {
  filter = "name eq '${var.subnet_name}'"
}

# Image Service lookup, image path only. v4 exposes only a plural list data
# source; filter on name (OData) and index into the single match.
data "nutanix_images_v2" "this" {
  count = var.source_type == "image" ? 1 : 0

  filter = "name eq '${var.image_name}'"
}

# Category UUID resolution, image path only.
# nutanix_virtual_machine_v2 requires each applied category as an ext_id (UUID),
# not a name/value pair. There is no singular by-name lookup, so resolve every
# (key, value) pair in local.vm_categories through the plural list data source,
# filtering on key + value and indexing into the single match. One lookup per
# category (~10 mandatory + any extra_tags) is issued at plan time.
data "nutanix_categories_v2" "this" {
  for_each = local.use_image_path ? local.vm_categories : {}

  filter = "key eq '${each.key}' and value eq '${each.value}'"
}

# VM Template lookup, template path only. v4 API has no singular by-name
# data source, so filter the list endpoint on templateName (OData) and
# index into the single match in nutanix_vm.tf.
data "nutanix_templates_v2" "this" {
  count = var.source_type == "template" ? 1 : 0

  filter = "templateName eq '${var.template_name}'"
}
