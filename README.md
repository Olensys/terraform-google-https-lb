# terraform-google-https-lb

Global external HTTPS load balancer with managed certificates, HTTP redirect, serverless NEG, NEG and bucket backends, optional CDN and Cloud Armor

## Opinions

- HTTPS only: a Google-managed certificate for `domains`; HTTP on port 80 only redirects (301) unless `http_redirect = false`.
- SSL policy `MODERN` with minimum TLS 1.2, created by the module and attached to the HTTPS proxy.
- QUIC (HTTP/3) is on.
- Cloud Logging is on for every backend service with a sample rate of 1.0.
- One URL map for every backend type: each backend's `paths` route to it, `default_backend` serves the rest.
- `security_policy` (a Cloud Armor policy self link) is attached to every `cloud_run` and `neg` backend service; `enable_cdn` applies to all backends.
- Health-check firewall rules are not created: serverless NEGs need none, and for zonal NEGs the network owner must allow `130.211.0.0/22` and `35.191.0.0/16`.
- The certificate name carries a random suffix (`random_certificate_suffix = true`), so changing `domains` never collides with the existing certificate name.
- Labels go on the address and forwarding rules; URL maps, certificates, NEGs and backend buckets do not accept labels.

### Backend types

| `type` | Required fields | What the module creates | Cloud Armor | Notes |
| ------ | --------------- | ----------------------- | ----------- | ----- |
| `cloud_run` | `service_name`, `region` | Serverless NEG plus backend service | yes | No health check; the NEG is regional. |
| `neg` | `neg_id` | Backend service for an existing NEG | yes | `neg_id` is the id or self link of a zonal `GCE_VM_IP_PORT` NEG, balanced by RATE (100 requests per second per endpoint) with an HTTP health check on the serving port. Internet NEGs are not supported in v1.0.x. |
| `bucket` | `bucket_name` | Backend bucket | no | Cloud Armor does not apply to backend buckets. |

Every backend other than `default_backend` needs `paths` other than `["/*"]`.
- `context.extra_tags` keys and values are normalised to valid GCP label syntax (lowercase, `[^a-z0-9_-]` → `-`, 63 chars); `labels` are applied verbatim and win.

## Usage

```hcl
variable "context" {
  default = {
    organization = "olensys"
    environment  = "dev"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }
}

module "naming" {
  source  = "git::https://github.com/Olensys/terraform-null-naming.git?ref=v1.0.1"
  context = var.context
}

module "this" {
  source = "git::https://github.com/Olensys/terraform-google-https-lb.git?ref=v1.1.0"

  name       = module.naming.name
  project_id = "my-project"
  context = var.context

  domains = ["app.example.com"]
  backends = {
    web    = { type = "cloud_run", service_name = "web", region = "us-central1" }
    static = { type = "bucket", bucket_name = "my-static-assets", paths = ["/static/*"] }
  }
  default_backend = "web"

  labels = module.naming.labels
}
```

The upstream module also uses `google-beta`, so both providers are required. Neither provider needs a default project; every resource sets `project` explicitly.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.0, < 8.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >= 6.0, < 8.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | >= 6.0, < 8.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_this"></a> [this](#module\_this) | terraform-google-modules/lb-http/google//modules/dynamic_backends | 14.2.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_backend_bucket.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_bucket) | resource |
| [google_compute_region_network_endpoint_group.cloud_run](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_network_endpoint_group) | resource |
| [google_compute_ssl_policy.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ssl_policy) | resource |
| [google_compute_url_map.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_backends"></a> [backends](#input\_backends) | Backends keyed by a short name (lowercase letters, digits, hyphens). type is one of:<br/>cloud\_run (needs service\_name and region; a serverless NEG is created), neg (needs neg\_id, an existing zonal GCE\_VM\_IP\_PORT NEG id or self link),<br/>bucket (needs bucket\_name; a backend bucket is created). paths are the URL paths routed to the backend; the default backend<br/>serves everything else, every other backend needs paths other than ["/*"]. | <pre>map(object({<br/>    type         = string<br/>    service_name = optional(string)<br/>    region       = optional(string)<br/>    neg_id       = optional(string)<br/>    bucket_name  = optional(string)<br/>    paths        = optional(list(string), ["/*"])<br/>  }))</pre> | n/a | yes |
| <a name="input_context"></a> [context](#input\_context) | Deployment context used for naming, tagging and environment-dependent defaults. | <pre>object({<br/>    organization = string<br/>    environment  = string<br/>    application  = string<br/>    component    = optional(string)<br/>    owner        = string<br/>    cost_center  = string<br/>    extra_tags   = optional(map(string), {})<br/>  })</pre> | n/a | yes |
| <a name="input_default_backend"></a> [default\_backend](#input\_default\_backend) | Key of the backend in backends that serves requests matching no other backend's paths. | `string` | n/a | yes |
| <a name="input_domains"></a> [domains](#input\_domains) | Domains covered by the Google-managed SSL certificate. DNS for each must point at external\_ip for the certificate to provision. | `list(string)` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Load balancer name, used as the prefix of every resource. Lowercase letters, digits and hyphens, starting with a letter, at most 48 characters, so the longest derived name ("<name>-https-redirect") stays within Google's 63-character limit. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project that owns the load balancer and its backends. | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | Whether to create any resources. Set false to create nothing. | `bool` | `true` | no |
| <a name="input_enable_cdn"></a> [enable\_cdn](#input\_enable\_cdn) | Enable Cloud CDN on every backend. | `bool` | `false` | no |
| <a name="input_http_redirect"></a> [http\_redirect](#input\_http\_redirect) | Redirect HTTP (port 80) to HTTPS with a 301. When false, port 80 serves the same backends as HTTPS. | `bool` | `true` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels merged onto the resources that accept them (the address and forwarding rules); applied last. | `map(string)` | `{}` | no |
| <a name="input_security_policy"></a> [security\_policy](#input\_security\_policy) | Self link of a Cloud Armor security policy attached to every cloud\_run and neg backend service. Null attaches none. (Backend buckets do not accept security policies.) | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_backend_config"></a> [backend\_config](#output\_backend\_config) | Sanitized map of the backend services passed to the upstream module, keyed like backends (cloud\_run and neg only). Null when create is false. |
| <a name="output_external_ip"></a> [external\_ip](#output\_external\_ip) | Global external IPv4 address of the load balancer; point the DNS records for domains at it. Null when create is false. |
| <a name="output_id"></a> [id](#output\_id) | ID of the URL map. Null when create is false. |
| <a name="output_labels"></a> [labels](#output\_labels) | Labels applied to the resources that accept them, with context.extra\_tags merged in. Null when create is false. |
| <a name="output_lb_settings"></a> [lb\_settings](#output\_lb\_settings) | HTTPS settings handed to the upstream module: ssl, https\_redirect, quic, random\_certificate\_suffix, managed\_certificate\_domains. Null when create is false. |
| <a name="output_name"></a> [name](#output\_name) | Load balancer name (prefix of every resource). Null when create is false. |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | Self link of the URL map. Null when create is false. |
| <a name="output_ssl_policy_profile"></a> [ssl\_policy\_profile](#output\_ssl\_policy\_profile) | Profile of the SSL policy attached to the HTTPS proxy. Null when create is false. |
| <a name="output_url_map_id"></a> [url\_map\_id](#output\_url\_map\_id) | ID of the URL map routing to the backends. Null when create is false. |
<!-- END_TF_DOCS -->
