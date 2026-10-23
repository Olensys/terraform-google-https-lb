terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = { source = "hashicorp/google", version = ">= 6.0, < 8.0" }
  }
}

variable "project_id" {
  description = "Project that owns the load balancer."
  type        = string
}

variable "service_name" {
  description = "Name of an existing Cloud Run service in us-central1."
  type        = string
}

variable "domain" {
  description = "Domain served by the load balancer."
  type        = string
}

module "this" {
  source = "../../"

  name       = "example"
  project_id = var.project_id
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }

  domains = [var.domain]
  backends = {
    web = { type = "cloud_run", service_name = var.service_name, region = "us-central1" }
  }
  default_backend = "web"
}

output "external_ip" {
  description = "Address to point the domain at."
  value       = module.this.external_ip
}
