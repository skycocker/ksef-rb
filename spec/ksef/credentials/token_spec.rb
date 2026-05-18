# frozen_string_literal: true

RSpec.describe Ksef::Credentials::Token do
  it "stores its value and reports type" do
    token = described_class.new("secret-token")
    expect(token.value).to eq("secret-token")
    expect(token.type).to eq(:token)
  end

  it "rejects blank values" do
    expect { described_class.new(nil) }.to raise_error(Ksef::ConfigurationError)
    expect { described_class.new("") }.to raise_error(Ksef::ConfigurationError)
  end

  it "redacts inspect output to avoid leaking the value" do
    token = described_class.new("super-secret")
    expect(token.inspect).not_to include("super-secret")
    expect(token.inspect).to include("[REDACTED]")
  end
end

RSpec.describe Ksef::Credentials::Certificate do
  it "raises NotImplementedError until certificate auth lands" do
    expect { described_class.new }.to raise_error(NotImplementedError)
  end
end
