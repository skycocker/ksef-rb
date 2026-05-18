# ksef-rb

Ruby client for the Polish [KSeF 2.0](https://ksef.podatki.gov.pl/) (Krajowy
System e-Faktur) National e-Invoicing System.

Targets the FA(3) schema (mandatory since February 2026). Built against the
official OpenAPI spec at `https://api-test.ksef.mf.gov.pl/docs/v2/openapi.json`
and the [CIRFMF reference clients](https://github.com/CIRFMF) for C# and Java.

## Status

Pre-1.0. The public API is small on purpose and stable across the v0.1 line,
but additions are expected as more KSeF features land.

## Installation

```ruby
gem "ksef-rb", require: "ksef"
```

## Quick start

```ruby
require "ksef"

Ksef.configure do |c|
  c.environment = :test          # :test, :demo, or :production
  c.user_agent  = "MyApp / ksef-rb #{Ksef::VERSION}"
end

client = Ksef::Client.new(
  nip:         "1234567890",
  credentials: Ksef::Credentials::Token.new(ENV.fetch("KSEF_TOKEN"))
)

client.sessions.with_interactive do |_session|
  headers = client.invoices.query(
    subject_type: :recipient,
    date_from:    Time.now.utc - (7 * 24 * 3600),
    date_to:      Time.now.utc
  )

  headers.each do |h|
    puts "#{h.ksef_reference_number}  #{h.issuer_nip}  #{h.gross_amount} #{h.currency}"
  end

  xml = client.invoices.fetch_xml(headers.first.ksef_reference_number)
  File.write("invoice.xml", xml)
end
```

`Ksef::InvoiceHeader` exposes (among others):
`ksef_reference_number`, `invoice_number`, `issuer_nip`, `issuer_name`,
`recipient_nip`, `recipient_name`, `issued_on`, `gross_amount`, `net_amount`,
`vat_amount`, `currency`, `invoicing_mode`, `invoice_type`, `form_code`,
`form_schema_version`, `permanently_stored_at`, `has_attachment?`,
`self_invoicing?`, and the original payload via `raw`.

## Authentication

v0.1 ships with token-based auth using the long-lived integration tokens minted
in the KSeF portal after a Profil Zaufany / qualified-seal login.

The full handshake — `/auth/challenge`, `/auth/ksef-token`, status polling at
`/auth/{ref}`, and `/auth/token/redeem` — is performed automatically by
`Ksef::Sessions#with_interactive`. The integration token is encrypted with
RSA-OAEP (SHA-256) using the public key returned by
`/security/public-key-certificates`.

`with_interactive` always tears the session down by calling
`DELETE /auth/sessions/current`, even when the block raises.

## Errors

All KSeF-specific errors inherit from `Ksef::Error`:

| Class                  | When                                         |
|------------------------|----------------------------------------------|
| `Ksef::AuthError`      | 401, 403, or auth-status failure (`code: 450`, etc.) |
| `Ksef::NotFoundError`  | 404                                          |
| `Ksef::RateLimitError` | 429 (exposes `#retry_after` in seconds when sent) |
| `Ksef::ServerError`    | 5xx                                          |
| `Ksef::ClientError`    | other 4xx                                    |
| `Ksef::ConfigurationError` | bad config                               |

Every error captures `status`, `body`, and the KSeF-supplied `code`.

## What's not in v0.1.0

| Feature                                 | Status |
|-----------------------------------------|--------|
| Token-based auth                        | shipped |
| Interactive sessions                    | shipped |
| Inbound invoice metadata query          | shipped |
| Inbound invoice XML fetch               | shipped |
| Inbound invoice PDF visualisation       | **stubbed** — KSeF 2.0 has no server-side PDF endpoint; render client-side from the XML using the official XSLT (`wizualizacja-faktury_v3-0.xsl`) |
| Certificate-based auth (qualified seal) | **stubbed** (`Ksef::Credentials::Certificate`) |
| Batch sessions                          | not yet  |
| Outbound invoice issuance               | not yet  |
| UPO download                            | **stubbed** (`Ksef::Invoices#fetch_upo`) |
| Offline / QR-code modes                 | not yet  |

`NotImplementedError` is raised from the stubs.

## Configuration reference

```ruby
Ksef.configure do |c|
  c.environment  = :test        # :test, :demo, :production
  c.user_agent   = "..."        # appended to every request
  c.timeout      = 30           # seconds
  c.open_timeout = 10           # seconds
  c.api_version  = "v2"         # path segment; defaults to v2
  c.base_url     = nil          # override entirely (useful for tests)
  c.logger       = Logger.new($stdout)  # wires Faraday's logger middleware
end
```

`Ksef::Client.new(configuration:)` accepts a per-client `Configuration`,
which is the duplicated global configuration by default.

## Development

```sh
bundle install
bundle exec rspec
```

The suite uses VCR (opt-in, via the `:vcr` metadata tag) and WebMock. Live
re-recording against the sandbox is gated behind `KSEF_RECORD=true` and a
real token in `KSEF_TOKEN`.

## License

MIT — see [LICENSE.txt](LICENSE.txt).
