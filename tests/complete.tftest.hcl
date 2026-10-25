# Run only by the nightly integration workflow, against real cloud credentials.
# Requires TF_VAR_project_id; TF_VAR_domain is optional.
run "apply_minimal" {
  command = apply

  module {
    source = "./examples/minimal"
  }

  assert {
    condition     = output.external_ip != null
    error_message = "The load balancer must receive an external IP."
  }
}
