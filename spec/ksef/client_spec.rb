# frozen_string_literal: true

RSpec.describe Ksef::Client do
  it "rejects a blank NIP" do
    expect do
      described_class.new(nip: "", credentials: Ksef::Credentials::Token.new("x"))
    end.to raise_error(Ksef::ConfigurationError)
  end

  it "captures NIP and credentials" do
    creds = Ksef::Credentials::Token.new("tok")
    client = described_class.new(nip: "1234567890", credentials: creds)
    expect(client.nip).to eq("1234567890")
    expect(client.credentials).to be(creds)
    expect(client.current_session).to be_nil
  end

  it "duplicates the global configuration so per-client overrides don't leak" do
    Ksef.configure { |c| c.user_agent = "global" }
    client = SpecSupport.build_client
    client.configuration.user_agent = "per-client"
    expect(Ksef.configuration.user_agent).to eq("global")
  end

  it "lazily exposes sessions and invoices" do
    client = SpecSupport.build_client
    expect(client.sessions).to be_a(Ksef::Sessions)
    expect(client.invoices).to be_a(Ksef::Invoices)
    expect(client.sessions).to be(client.sessions)
    expect(client.invoices).to be(client.invoices)
  end
end
