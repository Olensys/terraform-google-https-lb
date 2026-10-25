terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google      = { source = "hashicorp/google", version = ">= 6.0, < 8.0" }
    google-beta = { source = "hashicorp/google-beta", version = ">= 6.0, < 8.0" }
  }
}

variable "project_id" {
  description = "Project that owns the load balancer."
  type        = string
}

variable "domain" {
  description = "Domain served by the load balancer."
  type        = string
  default     = "lb.tf-test.olensys.com"
}

resource "google_cloud_run_v2_service" "hello" {
  project             = var.project_id
  name                = "olensys-test-lb-hello"
  location            = "us-central1"
  ingress             = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  deletion_protection = false

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
    }
  }
}

module "this" {
  source = "../../"

  name       = "olensys-test-lb"
  project_id = var.project_id
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "lb"
    owner        = "platform"
    cost_center  = "eng"
  }

  domains = [var.domain]
  backends = {
    web = { type = "cloud_run", service_name = google_cloud_run_v2_service.hello.name, region = "us-central1" }
  }
  default_backend = "web"
}

output "external_ip" {
  description = "Address to point the domain at."
  value       = module.this.external_ip
}
