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
