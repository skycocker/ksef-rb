# ksef-rb — agent / contributor notes

Ruby client for the Polish KSeF 2.0 (Krajowy System e-Faktur) National
e-Invoicing System. Targets the FA(3) schema, mandatory since February 2026.

Pre-1.0. The v0.1.x line is intentionally small; the public API is stable
across v0.1.x but additions are expected.

## Tech

- Pure Ruby, no Rails dependency.
- Required Ruby: `>= 3.2.0`.
- HTTP: Faraday (>= 2, < 3) + faraday-retry.
- XML: Nokogiri (>= 1.15) — currently only used in tests, but declared as a
  runtime dep so consumers can parse the FA(3) XML returned by
  `Invoices#fetch_xml` without adding it themselves.
- Auth: RSA-OAEP / SHA-256 (encrypting the integration token with the public
  key returned by `/security/public-key-certificates`).

## Run

```sh
bundle install
bundle exec rspec        # 63 examples, ~99% line coverage
bundle exec rubocop      # style only; not run in CI as hard fail (yet)
```

CI: `.github/workflows/ci.yml` runs RSpec on Ruby 3.2 / 3.3 / 3.4 and RuboCop
(continue-on-error) on push.

## Architecture

| File | Role |
|---|---|
| `lib/ksef.rb` | Top-level module + `Ksef.configure { |c| ... }` |
| `lib/ksef/version.rb` | `VERSION` constant |
| `lib/ksef/configuration.rb` | Per-instance / global configuration (env, base URL, timeouts, UA) |
| `lib/ksef/credentials/token.rb` | Long-lived KSeF integration token wrapper. Redacts in `#inspect`. |
| `lib/ksef/credentials/certificate.rb` | Stub — qualified-seal cert auth is a future XAdES project |
| `lib/ksef/internal/connection.rb` | Faraday wiring. Anything under `Ksef::Internal::*` is non-public. |
| `lib/ksef/internal/token_encryptor.rb` | RSA-OAEP/SHA-256 encryption of the integration token for `/auth/ksef-token` |
| `lib/ksef/sessions.rb` | Interactive-session lifecycle (`#with_interactive`, `#open`, `#terminate`) |
| `lib/ksef/session.rb` | Value object: reference number, access/refresh tokens, terminated? |
| `lib/ksef/invoices.rb` | `#query`, `#fetch_xml`, plus stubs for visualisation + UPO |
| `lib/ksef/invoice_header.rb` | Value object for one entry in `/invoices/query/metadata` |
| `lib/ksef/client.rb` | The user-facing entry point — `.sessions`, `.invoices`, `.connection`, `.current_session` |
| `lib/ksef/errors.rb` | Typed errors: `AuthError`, `NotFoundError`, `ClientError`, `ServerError`, `RateLimitError`, `ConfigurationError`, base `Error` |

## KSeF 2.0 quirks worth knowing

- **Base URL ends in `/v2`** — not `/api/online/...`. v1 docs and most online
  examples use the v1 path shape; ignore them. Authoritative URL:
  `https://api-test.ksef.mf.gov.pl/v2`.
- **OpenAPI spec**:
  `https://api-test.ksef.mf.gov.pl/docs/v2/openapi.json` (3.0.4 JSON).
- **Auth flow** (interactive session):
  1. `POST /auth/challenge` → `{ challenge, timestamp, timestampMs, clientIp }`
  2. Encrypt the integration token with RSA-OAEP/SHA-256 using the public key
     from `/security/public-key-certificates` (filter usage `KsefTokenEncryption`).
  3. `POST /auth/ksef-token` with the encrypted token + challenge → `{ referenceNumber, authenticationToken }`
  4. Poll `GET /auth/{ref}` until `status.code == 200`.
  5. `POST /auth/token/redeem` → `{ accessToken, refreshToken }`.
  6. Use `Bearer <accessToken>` on subsequent calls.
  7. `DELETE /auth/sessions/current` to close.
- **Inbound query**: `POST /invoices/query/metadata` with body containing
  `subjectType` ("Subject1"=issuer / "Subject2"=recipient / "Subject3" /
  "SubjectAuthorized") and `dateRange.dateType`
  ("Issue" / "Invoicing" / "PermanentStorage").
- **No PDF endpoint exists in v2.** Visualisations must be rendered
  client-side via the official XSLT (`wizualizacja-faktury_v3-0.xsl`) from
  `github.com/CIRFMF/ksef-docs`. `fetch_visualisation` raises
  `NotImplementedError` accordingly.
- **No recipient-side UPO endpoint exists.** UPO retrieval is scoped to the
  *sender* session that produced it. Recipients can only get the XML +
  metadata.

## Testing strategy

- Default: WebMock stubs. `WebMock.disable_net_connect!` is asserted at boot
  *and* after VCR's webmock hook flips it, so unmatched requests cannot leak
  to the live API even if VCR records partially.
- VCR is **opt-in**, tagged via RSpec metadata (`:vcr`). Cassettes live in
  `spec/vcr_cassettes/`.
- One hand-crafted cassette ships
  (`spec/vcr_cassettes/inbound_query_and_fetch.yml`) — synthesised from the
  OpenAPI spec + the CIRFMF reference clients. It's labelled as synthetic.
- Re-recording against the sandbox is gated behind two env vars:
  ```sh
  KSEF_RECORD=true KSEF_TOKEN=... bundle exec rspec spec/ksef/integration_spec.rb
  ```
  `<KSEF_TOKEN>` is filtered out of cassettes via
  `config.filter_sensitive_data` so you can commit them safely.
- Coverage is measured by SimpleCov (`coverage/`). Goal: ≥ 95% line coverage
  on `lib/ksef/**`. v0.1.0 sits at 98.87%.

## Stubs / known gaps

| Stub | Why |
|---|---|
| `Ksef::Credentials::Certificate` | Qualified-seal cert auth needs a XAdES signer; meaningful project on its own. |
| `Ksef::Invoices#fetch_visualisation` | No server endpoint exists; client-side XSLT only. |
| `Ksef::Invoices#fetch_upo` | Recipient-side endpoint doesn't exist; sender-side is tied to outbound sessions. |
| Outbound invoice issuance | Not yet — adds `POST /sessions/online/{ref}/invoices`, batch sessions, FA(3) XML composition. |
| Batch sessions | Not yet — `POST /sessions/batch`. |
| Offline / QR code modes | Not yet. |

All stubs raise `NotImplementedError` with a descriptive message and a hint
about what would be needed to implement them.

## Extending the gem — house style

- **Pure Ruby.** No Rails, no ActiveSupport. Reach for stdlib first.
- **Public API is what's documented**, period. Anything under
  `Ksef::Internal::*` (or marked `@api private`) is a free-fire zone.
- **Typed errors.** Every response status maps to a class; consumers should
  never have to match on integers.
- **No surprise network calls.** Every spec must run under
  `WebMock.disable_net_connect!`.
- **Cassettes are documentation.** When you add an endpoint, add at least
  one happy-path cassette synthesised from the OpenAPI spec, plus WebMock
  stubs for the error cases.
- **String → Symbol mapping at the boundary** (`SUBJECT_TYPE_MAP`,
  `DATE_TYPE_MAP`). Don't leak raw KSeF strings into the public API.
- **Value objects over hashes** (`InvoiceHeader`, `Session`) — but always
  expose `#raw` so advanced callers can drop down.

## Publishing

The canonical repo is `github.com/skycocker/ksef-rb`. The probau-rails app
develops the gem inside `vendor/ksef-rb/` (referenced via `path:` in its
Gemfile) and syncs out with `git subtree push`:

```sh
# from probau-rails root
git subtree push --prefix=vendor/ksef-rb https://github.com/skycocker/ksef-rb.git main
```

The gem isn't published to RubyGems yet; bumping the version and `gem build
+ gem push` is the remaining step before consumers outside probau-rails can
`gem install ksef-rb`.
