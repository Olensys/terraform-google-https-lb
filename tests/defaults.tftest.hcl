mock_provider "google" {}
mock_provider "google-beta" {}

variables {
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }
  name       = "example"
  project_id = "example-project"
  domains    = ["app.example.com"]
  backends = {
    web = { type = "cloud_run", service_name = "web", region = "us-central1" }
  }
  default_backend = "web"
}

run "test_http_redirect_default" {
  command = plan

  # SMOKE: asserts the redirect flag the wrapper hands to upstream; the redirect URL map lives in the child
  # module, so the real check is complete.tftest.hcl.
  assert {
    condition     = output.lb_settings.https_redirect == true
    error_message = "HTTP to HTTPS redirect must be on by default."
  }

  assert {
    condition     = output.lb_settings.random_certificate_suffix == true
    error_message = "The certificate name must carry a random suffix."
  }

  assert {
    condition     = output.lb_settings.quic == true
    error_message = "QUIC must be enabled."
  }
}

run "test_http_redirect_off" {
  command = plan

  variables {
    http_redirect = false
  }

  assert {
    condition     = output.lb_settings.https_redirect == false
    error_message = "http_redirect = false must disable the redirect."
  }
}

run "test_backend_per_key" {
  command = plan

  variables {
    backends = {
      web    = { type = "cloud_run", service_name = "web", region = "us-central1" }
      api    = { type = "cloud_run", service_name = "api", region = "europe-west1", paths = ["/api/*"] }
      legacy = { type = "neg", neg_id = "projects/p/zones/us-central1-a/networkEndpointGroups/legacy", paths = ["/legacy/*"] }
      static = { type = "bucket", bucket_name = "example-static", paths = ["/static/*"] }
    }
  }

  assert {
    condition     = length(google_compute_region_network_endpoint_group.cloud_run) == 2
    error_message = "One serverless NEG per cloud_run backend."
  }

  assert {
    condition     = length(google_compute_backend_bucket.this) == 1
    error_message = "One backend bucket per bucket backend."
  }

  assert {
    condition     = length(google_compute_url_map.this[0].path_matcher[0].path_rule) == 3
    error_message = "One path rule per non-default backend."
  }

  assert {
    condition = alltrue([
      for p in ["/api/*", "/legacy/*", "/static/*"] :
      contains(flatten([for r in google_compute_url_map.this[0].path_matcher[0].path_rule : r.paths]), p)
    ])
    error_message = "Every fixture path must appear in a path rule."
  }

  assert {
    condition     = output.backend_config.legacy.groups[0].balancing_mode == "RATE" && output.backend_config.legacy.groups[0].max_rate_per_endpoint == 100
    error_message = "neg backends must use RATE balancing with max_rate_per_endpoint 100."
  }

  assert {
    condition     = try(output.backend_config.web.groups[0].balancing_mode, null) == null
    error_message = "cloud_run backends must not set a balancing mode."
  }

  assert {
    condition     = toset(keys(output.backend_config)) == toset(["web", "api", "legacy"])
    error_message = "Upstream backend services are created for cloud_run and neg backends only."
  }
}

run "test_managed_cert_for_domains" {
  command = plan

  # SMOKE: asserts the domain list handed to upstream; the managed certificate resource lives in the child
  # module, so the real check is complete.tftest.hcl.
  variables {
    domains = ["a.example.com", "b.example.com"]
  }

  assert {
    condition     = output.lb_settings.managed_certificate_domains == tolist(["a.example.com", "b.example.com"]) && output.lb_settings.ssl == true
    error_message = "Managed certificate must cover exactly the given domains with ssl on."
  }
}

run "test_security_policy_attached" {
  command = plan

  # SMOKE: asserts the policy passed to each upstream backend service; the attachment itself is a child-module
  # attribute proven by complete.tftest.hcl.
  variables {
    security_policy = "projects/example-project/global/securityPolicies/waf"
    backends = {
      web = { type = "cloud_run", service_name = "web", region = "us-central1" }
      neg = { type = "neg", neg_id = "projects/p/zones/z/networkEndpointGroups/n", paths = ["/n/*"] }
    }
  }

  assert {
    condition     = alltrue([for k, b in output.backend_config : b.security_policy == "projects/example-project/global/securityPolicies/waf"])
    error_message = "security_policy must be attached to every backend service."
  }
}

run "test_cdn_per_backend" {
  command = plan

  variables {
    enable_cdn = true
  }

  assert {
    condition     = output.backend_config.web.enable_cdn == true && output.backend_config.web.log_config.enable == true && output.backend_config.web.log_config.sample_rate == 1
    error_message = "enable_cdn must propagate and Cloud Logging must be on with sample rate 1.0."
  }
}

run "test_ssl_policy_modern" {
  command = plan

  assert {
    condition     = google_compute_ssl_policy.this[0].profile == "MODERN" && google_compute_ssl_policy.this[0].min_tls_version == "TLS_1_2"
    error_message = "SSL policy must be MODERN with TLS 1.2 minimum."
  }

  assert {
    condition     = output.ssl_policy_profile == "MODERN"
    error_message = "ssl_policy_profile output must be MODERN."
  }
}

run "test_create_false_plans_nothing" {
  command = plan

  variables {
    create = false
  }

  assert {
    condition = alltrue([
      output.id == null, output.name == null, output.self_link == null, output.external_ip == null,
      output.url_map_id == null, output.labels == null, output.backend_config == null,
      output.ssl_policy_profile == null, output.lb_settings == null,
    ])
    error_message = "Every output must be null when create is false."
  }

  assert {
    condition     = length(google_compute_region_network_endpoint_group.cloud_run) == 0 && length(google_compute_backend_bucket.this) == 0
    error_message = "No resources may be planned when create is false."
  }

  assert {
    condition     = length(google_compute_ssl_policy.this) == 0 && length(google_compute_url_map.this) == 0
    error_message = "No SSL policy or URL map may be planned when create is false."
  }
}

run "test_tags_contract" {
  command = plan

  variables {
    labels = { owner = "x" }
    context = {
      organization = "olensys"
      environment  = "test"
      application  = "example"
      owner        = "platform"
      cost_center  = "eng"
      extra_tags   = { owner = "y", team = "z" }
    }
  }

  assert {
    condition     = output.labels.owner == "x"
    error_message = "var.labels must win over context.extra_tags."
  }

  assert {
    condition     = output.labels.team == "z"
    error_message = "context.extra_tags must be merged into labels."
  }
}

run "test_default_backend_must_exist" {
  command = plan

  variables {
    default_backend = "missing"
  }

  expect_failures = [output.external_ip]
}

run "test_backend_type_validation" {
  command = plan

  variables {
    backends = {
      web = { type = "vm", service_name = "web", region = "us-central1" }
    }
  }

  expect_failures = [var.backends]
}

run "test_backend_required_fields" {
  command = plan

  variables {
    backends = {
      web = { type = "cloud_run", service_name = "web" }
    }
  }

  expect_failures = [output.external_ip]
}

run "test_secondary_backend_needs_paths" {
  command = plan

  variables {
    backends = {
      web = { type = "cloud_run", service_name = "web", region = "us-central1" }
      api = { type = "cloud_run", service_name = "api", region = "us-central1" }
    }
  }

  expect_failures = [output.external_ip]
}

run "test_domains_must_not_be_empty" {
  command = plan

  variables {
    domains = []
  }

  expect_failures = [var.domains]
}

run "test_name_length_validation" {
  command = plan

  variables {
    name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  expect_failures = [var.name]
}

run "test_name_max_length_accepted" {
  command = plan

  variables {
    name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  assert {
    condition     = output.name == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    error_message = "A 48-character name must be accepted."
  }
}

run "test_name_rejects_uppercase" {
  command = plan

  variables {
    name = "Bad-Name"
  }

  expect_failures = [var.name]
}
