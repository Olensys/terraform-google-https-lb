variable "name" {
  description = "Load balancer name, used as the prefix of every resource. Lowercase letters, digits and hyphens, at most 50 characters (leaves room for the backend suffixes within Google's 63-character limit)."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,49}$", var.name))
    error_message = "name must match ^[a-z][a-z0-9-]{0,49}$ (at most 50 characters, starting with a letter)."
  }
}

variable "context" {
  description = "Deployment context used for naming, tagging and environment-dependent defaults."
  type = object({
    organization = string
    environment  = string
    application  = string
    component    = optional(string)
    owner        = string
    cost_center  = string
    extra_tags   = optional(map(string), {})
  })
  validation {
    condition     = contains(["dev", "staging", "prod", "test", "shared"], var.context.environment)
    error_message = "context.environment must be one of dev, staging, prod, test, shared."
  }
}

variable "project_id" {
  description = "Project that owns the load balancer and its backends."
  type        = string
}

variable "create" {
  description = "Whether to create any resources. Set false to create nothing."
  type        = bool
  default     = true
}

variable "domains" {
  description = "Domains covered by the Google-managed SSL certificate. DNS for each must point at external_ip for the certificate to provision."
  type        = list(string)
  validation {
    condition     = length(var.domains) > 0
    error_message = "domains must contain at least one domain."
  }
}

variable "backends" {
  description = <<-EOT
    Backends keyed by a short name (lowercase letters, digits, hyphens). type is one of:
    cloud_run (needs service_name and region; a serverless NEG is created), neg (needs neg_id, an existing NEG id or self link),
    bucket (needs bucket_name; a backend bucket is created). paths are the URL paths routed to the backend; the default backend
    serves everything else, every other backend needs paths other than ["/*"].
  EOT
  type = map(object({
    type         = string
    service_name = optional(string)
    region       = optional(string)
    neg_id       = optional(string)
    bucket_name  = optional(string)
    paths        = optional(list(string), ["/*"])
  }))
  validation {
    condition     = length(var.backends) > 0
    error_message = "backends must contain at least one backend."
  }
  validation {
    condition     = alltrue([for b in values(var.backends) : contains(["cloud_run", "neg", "bucket"], b.type)])
    error_message = "Every backend type must be one of cloud_run, neg, bucket."
  }
  validation {
    condition     = alltrue([for k in keys(var.backends) : can(regex("^[a-z][a-z0-9-]{0,11}$", k))])
    error_message = "Backend keys must match ^[a-z][a-z0-9-]{0,11}$."
  }
}

variable "default_backend" {
  description = "Key of the backend in backends that serves requests matching no other backend's paths."
  type        = string
}

variable "security_policy" {
  description = "Self link of a Cloud Armor security policy attached to every cloud_run and neg backend service. Null attaches none. (Backend buckets do not accept security policies.)"
  type        = string
  default     = null
}

variable "enable_cdn" {
  description = "Enable Cloud CDN on every backend."
  type        = bool
  default     = false
}

variable "http_redirect" {
  description = "Redirect HTTP (port 80) to HTTPS with a 301. When false, port 80 serves the same backends as HTTPS."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels merged onto the resources that accept them (the address and forwarding rules); applied last."
  type        = map(string)
  default     = {}
}
