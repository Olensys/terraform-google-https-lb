locals {
  extra_labels = { for k, v in var.context.extra_tags :
  substr(replace(lower(k), "/[^a-z0-9_-]/", "-"), 0, 63) => substr(replace(lower(v), "/[^a-z0-9_-]/", "-"), 0, 63) }
  labels = merge(local.extra_labels, var.labels)

  cloud_run_backends = { for k, b in var.backends : k => b if b.type == "cloud_run" }
  neg_backends       = { for k, b in var.backends : k => b if b.type == "neg" }
  bucket_backends    = { for k, b in var.backends : k => b if b.type == "bucket" }

  # cloud_run -> serverless NEG, neg -> existing NEG; both become upstream backend services.
  service_backends = merge(local.cloud_run_backends, local.neg_backends)

  backend_config = {
    for k, b in local.service_backends : k => {
      protocol        = "HTTP"
      port_name       = "http"
      enable_cdn      = var.enable_cdn
      security_policy = var.security_policy
      # Upstream dereferences cdn_policy whenever enable_cdn is true and needs the header list set.
      cdn_policy = { cache_mode = "CACHE_ALL_STATIC", bypass_cache_on_request_headers = []
        cache_key_policy = { include_host = true, include_protocol = true, include_query_string = true }
      }
      log_config = { enable = true, sample_rate = 1.0 }
      # Zonal NEGs need an explicit balancing mode; serverless NEGs take none.
      groups = [{
        group                 = b.type == "cloud_run" ? google_compute_region_network_endpoint_group.cloud_run[k].id : coalesce(b.neg_id, "unset")
        balancing_mode        = b.type == "neg" ? "RATE" : null
        max_rate_per_endpoint = b.type == "neg" ? 100 : null
      }]
      # Serverless NEGs take no health check or balancing mode; zonal / hybrid NEGs need both.
      health_check = b.type == "neg" ? { protocol = "HTTP", request_path = "/", port_specification = "USE_SERVING_PORT" } : null
    } if var.create
  }

  # Self links of every routable backend, keyed like var.backends.
  service_links = merge(
    { for k, b in local.service_backends : k => module.this[0].backend_services[k].self_link if var.create },
    { for k, b in google_compute_backend_bucket.this : k => b.self_link },
  )

  # An unknown default_backend is rejected by the output precondition; fall back to any backend so the error
  # surfaces there instead of as a provider schema error.
  default_service = try(local.service_links[var.default_backend], values(local.service_links)[0], null)

  path_rules = {
    for k, b in var.backends : k => [for p in b.paths : p if p != "/*"]
    if length([for p in b.paths : p if p != "/*"]) > 0
  }
}

resource "google_compute_region_network_endpoint_group" "cloud_run" {
  for_each = var.create ? local.cloud_run_backends : {}

  project               = var.project_id
  name                  = "${var.name}-${each.key}-neg"
  region                = coalesce(each.value.region, "unset") # missing fields are rejected by the output precondition
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = coalesce(each.value.service_name, "unset")
  }
}

resource "google_compute_backend_bucket" "this" {
  for_each = var.create ? local.bucket_backends : {}

  project     = var.project_id
  name        = "${var.name}-bucket-${each.key}"
  bucket_name = coalesce(each.value.bucket_name, "unset")
  enable_cdn  = var.enable_cdn
}

resource "google_compute_ssl_policy" "this" {
  count = var.create ? 1 : 0

  project         = var.project_id
  name            = "${var.name}-ssl"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

# One URL map for every backend type: path rules per backend, the default backend as fallback.
resource "google_compute_url_map" "this" {
  count = var.create ? 1 : 0

  project         = var.project_id
  name            = "${var.name}-url-map"
  default_service = local.default_service

  host_rule {
    hosts        = ["*"]
    path_matcher = "paths"
  }

  path_matcher {
    name            = "paths"
    default_service = local.default_service

    dynamic "path_rule" {
      for_each = local.path_rules
      content {
        paths   = path_rule.value
        service = local.service_links[path_rule.key]
      }
    }
  }
}

module "this" {
  source  = "terraform-google-modules/lb-http/google//modules/dynamic_backends"
  version = "14.2.0"

  count = var.create ? 1 : 0

  project = var.project_id
  name    = var.name
  labels  = local.labels

  backends = local.backend_config

  # Upstream would create a health-check firewall rule per network; serverless NEGs need none and zonal NEG
  # firewalls belong to the network owner (allow 130.211.0.0/22 and 35.191.0.0/16).
  firewall_networks = []

  create_url_map = false
  url_map        = google_compute_url_map.this[0].self_link

  ssl                             = true
  random_certificate_suffix       = true
  managed_ssl_certificate_domains = var.domains
  ssl_policy                      = google_compute_ssl_policy.this[0].self_link
  quic                            = true
  https_redirect                  = var.http_redirect
  http_forward                    = !var.http_redirect
}
