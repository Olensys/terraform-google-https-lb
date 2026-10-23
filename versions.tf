terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = { source = "hashicorp/google", version = ">= 6.0, < 8.0" }
    # The pinned upstream module creates its backend services and health checks with google-beta.
    google-beta = { source = "hashicorp/google-beta", version = ">= 6.0, < 8.0" }
  }
}
