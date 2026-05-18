# frozen_string_literal: true

RSpec.describe Ksef::Invoices do
  let(:client) { SpecSupport.build_client }
  let(:session) do
    Ksef::Session.new(
      reference_number: "session-1",
      access_token:     "access-jwt",
      refresh_token:    "refresh-jwt"
    )
  end

  before { client.current_session = session }

  describe "#query" do
    let(:metadata_body) do
      {
        "hasMore"     => false,
        "isTruncated" => false,
        "invoices"    => [
          {
            "ksefNumber"           => "5555555555-20250828-010080615740-E4",
            "invoiceNumber"        => "FA/2025/0001",
            "issueDate"            => "2025-08-27",
            "invoicingDate"        => "2025-08-28T09:22:13Z",
            "acquisitionDate"      => "2025-08-28T09:22:56Z",
            "permanentStorageDate" => "2025-08-28T09:23:01Z",
            "seller"               => { "nip" => "5555555555", "name" => "Pro Bau Sp. z o.o." },
            "buyer"                => {
              "identifier" => { "type" => "Nip", "value" => "1234567890" },
              "name"       => "Test Buyer"
            },
            "netAmount"      => 100.0,
            "grossAmount"    => 123.0,
            "vatAmount"      => 23.0,
            "currency"       => "PLN",
            "invoicingMode"  => "Online",
            "invoiceType"    => "Vat",
            "formCode"       => { "systemCode" => "FA (3)", "schemaVersion" => "1-0E", "value" => "FA" },
            "isSelfInvoicing" => false,
            "hasAttachment"  => false,
            "invoiceHash"    => "abc=="
          }
        ]
      }
    end

    it "POSTs the expected filter body and returns InvoiceHeader objects" do
      stub = stub_request(:post, SpecSupport.api_url("/invoices/query/metadata"))
             .with(
               headers: { "Authorization" => "Bearer access-jwt" },
               query:   { "pageOffset" => "0", "pageSize" => "100", "sortOrder" => "Asc" }
             ) do |req|
               body = JSON.parse(req.body)
               body["subjectType"] == "Subject2" &&
                 body["dateRange"]["dateType"] == "PermanentStorage" &&
                 body["dateRange"]["from"] &&
                 body["dateRange"]["to"]
             end
             .to_return(status: 200, body: metadata_body.to_json,
                        headers: { "Content-Type" => "application/json" })

      headers = client.invoices.query(
        date_from: Time.utc(2025, 8, 1),
        date_to:   Time.utc(2025, 9, 1)
      )

      expect(stub).to have_been_requested
      expect(headers.size).to eq(1)
      header = headers.first
      expect(header.ksef_reference_number).to eq("5555555555-20250828-010080615740-E4")
      expect(header.issuer_nip).to eq("5555555555")
      expect(header.issuer_name).to eq("Pro Bau Sp. z o.o.")
      expect(header.recipient_nip).to eq("1234567890")
      expect(header.invoice_number).to eq("FA/2025/0001")
      expect(header.gross_amount).to eq(123.0)
      expect(header.currency).to eq("PLN")
      expect(header.issued_on).to eq(Date.new(2025, 8, 27))
      expect(header.permanently_stored_at).to be_a(Time)
      expect(header.form_code).to eq("FA")
      expect(header.form_schema_version).to eq("1-0E")
      expect(header.self_invoicing?).to be(false)
      expect(header).not_to be_has_attachment
    end

    it "accepts Date and String date_from arguments" do
      stub = stub_request(:post, /invoices\/query\/metadata/).to_return(
        status: 200, body: { invoices: [] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      client.invoices.query(date_from: Date.new(2025, 1, 1))
      client.invoices.query(date_from: "2025-02-01T00:00:00Z")
      expect(stub).to have_been_requested.twice
    end

    it "translates :issuer to Subject1" do
      stub = stub_request(:post, /invoices\/query\/metadata/)
             .with do |req| JSON.parse(req.body)["subjectType"] == "Subject1" end
             .to_return(status: 200, body: { invoices: [] }.to_json,
                        headers: { "Content-Type" => "application/json" })

      client.invoices.query(subject_type: :issuer, date_from: "2025-01-01T00:00:00Z")
      expect(stub).to have_been_requested
    end

    it "raises ArgumentError on unknown subject_type" do
      expect do
        client.invoices.query(subject_type: :nope, date_from: "2025-01-01T00:00:00Z")
      end.to raise_error(ArgumentError, /Unknown subject_type/)
    end

    it "raises ArgumentError on unknown date_type" do
      expect do
        client.invoices.query(date_type: :nope, date_from: "2025-01-01T00:00:00Z")
      end.to raise_error(ArgumentError, /Unknown date_type/)
    end

    it "raises AuthError when no session is active" do
      client.current_session = nil
      expect do
        client.invoices.query(date_from: "2025-01-01T00:00:00Z")
      end.to raise_error(Ksef::AuthError, /No active KSeF session/)
    end

    it "raises AuthError when session is terminated" do
      session.mark_terminated!
      expect do
        client.invoices.query(date_from: "2025-01-01T00:00:00Z")
      end.to raise_error(Ksef::AuthError, /terminated/)
    end

    it "surfaces 401 as AuthError" do
      stub_request(:post, /invoices\/query\/metadata/)
        .to_return(status: 401, body: "{}", headers: { "Content-Type" => "application/json" })

      expect do
        client.invoices.query(date_from: "2025-01-01T00:00:00Z")
      end.to raise_error(Ksef::AuthError)
    end

    it "surfaces 500 as ServerError" do
      stub_request(:post, /invoices\/query\/metadata/)
        .to_return(status: 500, body: "{}", headers: { "Content-Type" => "application/json" })

      expect do
        client.invoices.query(date_from: "2025-01-01T00:00:00Z")
      end.to raise_error(Ksef::ServerError)
    end
  end

  describe "#fetch_xml" do
    let(:xml_payload) { "<Faktura>...</Faktura>" }

    it "returns the raw XML body" do
      stub_request(:get, SpecSupport.api_url("/invoices/ksef/ABC-1"))
        .with(headers: { "Authorization" => "Bearer access-jwt", "Accept" => "application/xml" })
        .to_return(status: 200, body: xml_payload,
                   headers: { "Content-Type" => "application/xml" })

      expect(client.invoices.fetch_xml("ABC-1")).to eq(xml_payload)
    end

    it "raises NotFoundError on 404" do
      stub_request(:get, SpecSupport.api_url("/invoices/ksef/MISSING"))
        .to_return(status: 404, body: "{}", headers: { "Content-Type" => "application/json" })

      expect { client.invoices.fetch_xml("MISSING") }.to raise_error(Ksef::NotFoundError)
    end

    it "validates the reference number argument" do
      expect { client.invoices.fetch_xml("") }.to raise_error(ArgumentError, /cannot be blank/)
      expect { client.invoices.fetch_xml(nil) }.to raise_error(ArgumentError, /cannot be blank/)
    end
  end

  describe "#fetch_visualisation" do
    it "is stubbed and raises NotImplementedError" do
      expect { client.invoices.fetch_visualisation("anything") }
        .to raise_error(NotImplementedError, /no public endpoint/i)
    end
  end

  describe "#fetch_upo" do
    it "is stubbed and raises NotImplementedError" do
      expect { client.invoices.fetch_upo("anything") }
        .to raise_error(NotImplementedError, /UPO/)
    end
  end
end
