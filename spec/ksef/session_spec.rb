# frozen_string_literal: true

RSpec.describe Ksef::Session do
  it "tracks termination state" do
    session = described_class.new(reference_number: "ref", access_token: "a", refresh_token: "r")
    expect(session).not_to be_terminated
    session.mark_terminated!
    expect(session).to be_terminated
  end

  it "redacts inspect" do
    session = described_class.new(reference_number: "ref", access_token: "secret", refresh_token: "secret2")
    expect(session.inspect).not_to include("secret")
  end
end

RSpec.describe Ksef::Error do
  it "captures status, body, and code" do
    err = described_class.new("boom", status: 418, body: { x: 1 }, code: 42)
    expect(err.message).to eq("boom")
    expect(err.status).to eq(418)
    expect(err.body).to eq(x: 1)
    expect(err.code).to eq(42)
  end
end

RSpec.describe Ksef::RateLimitError do
  it "captures retry-after metadata" do
    err = described_class.new("slow down", retry_after: 3)
    expect(err.retry_after).to eq(3)
  end
end
