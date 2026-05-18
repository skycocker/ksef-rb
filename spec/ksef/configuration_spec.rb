# frozen_string_literal: true

RSpec.describe Ksef::Configuration do
  it "defaults to the test environment" do
    expect(described_class.new.resolved_base_url).to eq("https://api-test.ksef.mf.gov.pl/v2")
  end

  it "resolves URL for demo and production" do
    config = described_class.new
    config.environment = :demo
    expect(config.resolved_base_url).to eq("https://api-demo.ksef.mf.gov.pl/v2")
    config.environment = :production
    expect(config.resolved_base_url).to eq("https://api.ksef.mf.gov.pl/v2")
  end

  it "honours a custom base URL" do
    config = described_class.new
    config.base_url = "https://example.invalid"
    expect(config.resolved_base_url).to eq("https://example.invalid/v2")
  end

  it "raises a ConfigurationError on unknown environment" do
    config = described_class.new
    config.environment = :wonderland
    expect { config.resolved_base_url }.to raise_error(Ksef::ConfigurationError, /Unknown KSeF environment/)
  end
end
