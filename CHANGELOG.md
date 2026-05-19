# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
