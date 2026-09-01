terraform {
  required_version = ">= 1.9"

  required_providers {
    nutanix = {
      source = "nutanix/nutanix"
      # Pinned exactly. 2.4.1 is published upstream but marked "Invalid
      # Release" in the provider CHANGELOG, so a range constraint such as
      # "~> 2.4" can resolve to a broken build. 2.4.2 is also the first
      # release supporting api_key authentication (#1062), which the site
      # repositories depend on.
      version = "2.4.2"
    }
  }
}
