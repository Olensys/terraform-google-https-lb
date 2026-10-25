# Changelog

## [1.1.3](https://github.com/Olensys/terraform-google-https-lb/compare/v1.1.2...v1.1.3) (2026-10-25)


### Bug Fixes

* **examples:** deploy the example Cloud Run service instead of requiring one ([#4](https://github.com/Olensys/terraform-google-https-lb/issues/4)) ([b1681bf](https://github.com/Olensys/terraform-google-https-lb/commit/b1681bf251ea29a8e79c18a91f8815d24e29f221))

## [1.1.2](https://github.com/Olensys/terraform-google-https-lb/compare/v1.1.1...v1.1.2) (2026-10-24)


### Bug Fixes

* **examples:** unique application slug so concurrent integration runs do not collide ([#2](https://github.com/Olensys/terraform-google-https-lb/issues/2)) ([adf3af0](https://github.com/Olensys/terraform-google-https-lb/commit/adf3af0bde7afc2a74f240bb5579e3564e86d0f1))

## [1.1.1](https://github.com/Olensys/terraform-google-https-lb/compare/v1.1.0...v1.1.1) (2026-10-24)


### Bug Fixes

* run integration on change and weekly instead of nightly ([aa80ee7](https://github.com/Olensys/terraform-google-https-lb/commit/aa80ee702a084ed77d597667d83ed24fb414ddad))

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
