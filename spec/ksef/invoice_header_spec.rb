# frozen_string_literal: true

RSpec.describe Ksef::InvoiceHeader do
  let(:raw) do
    {
      "ksefNumber"           => "K-1",
      "invoiceNumber"        => "FA/1",
      "issueDate"            => "2025-08-27",
      "acquisitionDate"      => "2025-08-28T09:22:56Z",
      "permanentStorageDate" => "2025-08-28T09:23:01Z",
      "seller"               => { "nip" => "5555555555", "name" => "Seller" },
      "buyer"                => { "identifier" => { "type" => "Nip", "value" => "1111111111" }, "name" => "Buyer" },
      "netAmount"            => 10.0,
      "grossAmount"          => 12.3,
      "vatAmount"            => 2.3,
      "currency"             => "PLN",
      "invoicingMode"        => "Online",
      "invoiceType"          => "Vat",
      "formCode"             => { "value" => "FA", "schemaVersion" => "1-0E" },
      "isSelfInvoicing"      => true,
      "hasAttachment"        => true,
      "invoiceHash"          => "h"
    }
  end

  it "parses dates, times, and nested identifiers" do
    header = described_class.new(raw)
    expect(header.ksef_reference_number).to eq("K-1")
    expect(header.issuer_nip).to eq("5555555555")
    expect(header.recipient_nip).to eq("1111111111")
    expect(header.issued_on).to eq(Date.new(2025, 8, 27))
    expect(header.acquired_at).to eq(Time.utc(2025, 8, 28, 9, 22, 56))
    expect(header.self_invoicing?).to be(true)
    expect(header).to be_has_attachment
    expect(header.raw).to be(raw)
  end

  it "tolerates missing / malformed dates" do
    header = described_class.new(raw.merge("issueDate" => "nope", "permanentStorageDate" => nil))
    expect(header.issued_on).to be_nil
    expect(header.permanently_stored_at).to be_nil
  end
end
