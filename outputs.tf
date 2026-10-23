output "id" {
  description = "ID of the URL map. Null when create is false."
  value       = var.create ? google_compute_url_map.this[0].id : null
}

output "name" {
  description = "Load balancer name (prefix of every resource). Null when create is false."
  value       = var.create ? var.name : null
}

output "self_link" {
  description = "Self link of the URL map. Null when create is false."
  value       = var.create ? google_compute_url_map.this[0].self_link : null
}

output "url_map_id" {
  description = "ID of the URL map routing to the backends. Null when create is false."
  value       = var.create ? google_compute_url_map.this[0].id : null
}

output "external_ip" {
  description = "Global external IPv4 address of the load balancer; point the DNS records for domains at it. Null when create is false."
  value       = var.create ? module.this[0].external_ip : null

  precondition {
    condition     = !var.create || contains(keys(var.backends), var.default_backend)
    error_message = "default_backend must be a key of backends."
  }

  precondition {
    condition = !var.create || alltrue([
      for k, b in var.backends : (
        b.type == "cloud_run" ? (b.service_name != null && b.region != null) :
        b.type == "neg" ? b.neg_id != null :
        b.bucket_name != null
      )
    ])
    error_message = "cloud_run backends need service_name and region, neg backends need neg_id, bucket backends need bucket_name."
  }

  precondition {
    condition = !var.create || alltrue([
      for k, b in var.backends : k == var.default_backend || length([for p in b.paths : p if p != "/*"]) > 0
    ])
    error_message = "Every backend other than default_backend needs paths other than \"/*\"."
  }

  precondition {
    condition     = !var.create || alltrue([for k in keys(var.backends) : length(var.name) + length(k) + 9 <= 63])
    error_message = "name plus backend key is too long: \"<name>-backend-<key>\" must stay within 63 characters."
  }
}

output "labels" {
  description = "Labels applied to the resources that accept them, with context.extra_tags merged in. Null when create is false."
  value       = var.create ? local.labels : null
}

output "backend_config" {
  description = "Sanitized map of the backend services passed to the upstream module, keyed like backends (cloud_run and neg only). Null when create is false."
  value       = var.create ? local.backend_config : null
}

output "ssl_policy_profile" {
  description = "Profile of the SSL policy attached to the HTTPS proxy. Null when create is false."
  value       = var.create ? google_compute_ssl_policy.this[0].profile : null
}

output "lb_settings" {
  description = "HTTPS settings handed to the upstream module: ssl, https_redirect, quic, random_certificate_suffix, managed_certificate_domains. Null when create is false."
  value = var.create ? {
    ssl                         = true
    https_redirect              = var.http_redirect
    quic                        = true
    random_certificate_suffix   = true
    managed_certificate_domains = var.domains
  } : null
}
