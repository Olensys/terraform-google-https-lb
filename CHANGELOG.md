# Changelog

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
