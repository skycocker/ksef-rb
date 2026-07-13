# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.3] - 2026-07-13

### Fixed
- Retry middleware: `Faraday::RetriableResponse` was missing from
  `Connection::RETRY_OPTIONS[:exceptions]`. Because that key overrides the
  faraday-retry default (which includes it), its absence silently disabled the
  `retry_statuses: [502, 503, 504]` retries **and** leaked the raw synthetic
  `Faraday::RetriableResponse` up the stack instead of mapping it to a typed
  `Ksef::ServerError`. Observed in production as an unretried gateway blip on
  `POST /auth/challenge` surfacing as `Faraday::RetriableResponse` rather than
  being absorbed. The class is now included, so 502/503/504 are retried up to
  `max` and, if still failing, raised as `Ksef::ServerError`. Added regression
  specs covering both retry-then-recover and retry-then-exhaust paths.

## [0.1.2] - 2026-05-19

### Fixed
- `/security/public-key-certificates` returns a DER-encoded X.509 certificate,
  not a bare SPKI. The previous `Internal::TokenEncryptor.normalize_public_key`
  fed the DER straight into `OpenSSL::PKey::RSA.new`, which raised
  `OpenSSL::PKey::PKeyError: Neither PUB key nor PRIV key` against the live
  production endpoint. The normaliser now parses the bytes as an X.509
  certificate and extracts the public key, falling back to the bare-key code
  path for backwards compatibility. The spec-helper fixture was updated to
  return a real self-signed X.509 cert (matching the real KSeF response shape)
  so the entire session lifecycle exercises this path.
- `Ksef::InvoiceHeader` now `require`s `"time"` explicitly. It calls
  `Time.iso8601` to parse `acquisitionDate` / `permanentStorageDate`; the spec
  suite happened to load `time` transitively via `webmock`, but a bare
  consumer that only required `"ksef"` got `NoMethodError: undefined method
  'iso8601' for class Time` the first time they pulled invoice metadata.

## [0.1.1] - 2026-05-19

### Added
- `lib/ksef-rb.rb` shim so `gem "ksef-rb"` works in any Gemfile without
  the `require: "ksef"` option. Consumers who already use the explicit
  `require:` form keep working unchanged.

## [0.1.0] - 2025-05-18

### Added
- `Ksef.configure` / `Ksef::Configuration` for environment selection
  (`:test`, `:demo`, `:production`) and request defaults.
- `Ksef::Credentials::Token` wrapping the long-lived KSeF integration token.
- `Ksef::Client` as the main entry point.
- `Ksef::Sessions` implementing the interactive-session lifecycle —
  `/auth/challenge` → RSA-OAEP/SHA-256 token encryption → `/auth/ksef-token`
  → status polling → `/auth/token/redeem` → `DELETE /auth/sessions/current`.
  Public API: `#with_interactive`, `#open`, `#terminate`.
- `Ksef::Invoices` for inbound retrieval — `#query` (metadata) and
  `#fetch_xml` (raw FA(3) XML).
- `Ksef::InvoiceHeader` value object exposing the business-meaningful slice
  of the `InvoiceMetadata` payload.
- Typed errors: `Ksef::AuthError`, `Ksef::NotFoundError`,
  `Ksef::RateLimitError` (with `retry_after`), `Ksef::ServerError`,
  `Ksef::ClientError`, `Ksef::ConfigurationError`, plus a base `Ksef::Error`.
- Stubs (`NotImplementedError`) for `Ksef::Credentials::Certificate`,
  `Ksef::Invoices#fetch_visualisation`, `Ksef::Invoices#fetch_upo`.
- RSpec suite (63 examples, ~99% line coverage) backed by WebMock plus a
  hand-crafted VCR cassette synthesised from the OpenAPI 3.0.4 spec and the
  CIRFMF reference clients. Re-recording against the live sandbox is gated
  by `KSEF_RECORD=true` and a `KSEF_TOKEN`.

[0.1.0]: https://github.com/skycocker/ksef-rb/releases/tag/v0.1.0
