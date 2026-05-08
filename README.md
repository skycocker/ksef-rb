# ksef-rb

Ruby client for the Polish [KSeF 2.0](https://ksef.podatki.gov.pl/) (Krajowy System e-Faktur)
National e-Invoicing System.

Targets the FA(3) schema (mandatory since February 2026). Built against the official
OpenAPI spec at `https://api-test.ksef.mf.gov.pl/docs/v2/openapi.json` and the
[CIRFMF reference clients](https://github.com/CIRFMF) for C# and Java.

## Status

Pre-alpha. The public API will change without notice until 1.0.

## Installation

```ruby
gem "ksef-rb", require: "ksef"
```

## Roadmap

- [ ] Authentication (token + qualified seal certificate)
- [ ] Interactive sessions
- [ ] Inbound invoice retrieval (FA(3) XML + visualisation PDF)
- [ ] UPO download
- [ ] Outbound invoice issuance
- [ ] Batch sessions
- [ ] Offline / QR code modes

## Development

```sh
bundle install
bundle exec rspec
```

## License

MIT — see [LICENSE.txt](LICENSE.txt).
