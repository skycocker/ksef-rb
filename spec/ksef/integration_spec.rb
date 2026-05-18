# frozen_string_literal: true

# VCR-backed sanity check exercising the resource layer (query + xml fetch)
# against a hand-crafted cassette.
#
# Because we don't have access to live sandbox credentials, the cassette below
# was synthesised from the OpenAPI 3.0.4 spec at
# https://api-test.ksef.mf.gov.pl/docs/v2/openapi.json and the CIRFMF reference
# clients (C#/Java). To re-record against the live sandbox set KSEF_RECORD=true
# and provide real credentials via the KSEF_TOKEN env var.
#
# The full auth handshake (challenge → ksef-token → poll → redeem → terminate)
# is exercised in `spec/ksef/sessions_spec.rb`. We bypass it here by injecting
# a pre-built Session, because the encryption payload sent to /auth/ksef-token
# is non-deterministic (random OAEP padding) and would not match a cassette.
RSpec.describe "Inbound invoice flow", :vcr do
  let(:client) { SpecSupport.build_client }
  let(:session) do
    Ksef::Session.new(
      reference_number: "20250514-AU-2DFC46C000-3AC6D5877F-D4",
      access_token:     "test-access-token",
      refresh_token:    "test-refresh-token"
    )
  end

  before { client.current_session = session }

  it "queries metadata then fetches the XML",
     vcr: { cassette_name: "inbound_query_and_fetch", match_requests_on: %i[method uri] } do
    headers = client.invoices.query(
      subject_type: :recipient,
      date_from:    "2025-08-01T00:00:00Z",
      date_to:      "2025-09-01T00:00:00Z"
    )
    expect(headers).not_to be_empty
    first = headers.first
    expect(first.ksef_reference_number).to be_a(String)

    xml = client.invoices.fetch_xml(first.ksef_reference_number)
    expect(xml).to include("Faktura")
  end
end
