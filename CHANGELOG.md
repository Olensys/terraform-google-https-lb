# Changelog

## 1.1.0

### Fixes

- normalise `context.extra_tags` keys and values to valid GCP label syntax (lowercase, invalid characters to `-`, 63 characters); `labels` still win
- declare `google-beta` in `examples/minimal`, matching the module's required providers

### Tests

- `test_tags_contract` covers a mixed-case tag key and a value with a space

### Docs

- README usage shows the naming module

### Behaviour changes

- `context.extra_tags` entries now appear as normalised labels (for example `Team = "Core Team"` becomes `team = "core-team"`). Callers that relied on unnormalised keys must read the normalised ones; values that previously failed GCP label validation now succeed.

## 1.0.1

### Fixes

- require name to start with a letter
- cap name at 48 characters, balance zonal NEGs by RATE, randomize certificate name suffix

### Tests

- cover path rules, neg balancing, name limit and create=false resources

### Docs

- document neg backends, certificate suffix and provider note

## 1.0.0

- Global external HTTPS load balancer: managed certificate, MODERN TLS 1.2 SSL policy, HTTP redirect, QUIC, Cloud Logging.
- cloud_run (serverless NEG), neg and bucket backends behind one path-routed URL map; optional Cloud CDN and Cloud Armor.
