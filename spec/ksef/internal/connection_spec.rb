# frozen_string_literal: true

RSpec.describe Ksef::Internal::Connection do
  subject(:connection) { described_class.new(Ksef::Configuration.new) }

  describe "error classification" do
    it "raises AuthError on 401" do
      stub_request(:get, SpecSupport.api_url("/auth/sessions/current"))
        .to_return(status: 401, body: { exception: { exceptionDetailList: [{ exceptionCode: 21301, exceptionDescription: "Brak autoryzacji" }] } }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect { connection.request(:get, "/auth/sessions/current") }
        .to raise_error(Ksef::AuthError) { |err|
          expect(err.status).to eq(401)
          expect(err.code).to eq(21_301)
        }
    end

    it "raises NotFoundError on 404" do
      stub_request(:get, SpecSupport.api_url("/invoices/ksef/MISSING"))
        .to_return(status: 404, body: "{}", headers: { "Content-Type" => "application/json" })

      expect { connection.request(:get, "/invoices/ksef/MISSING") }
        .to raise_error(Ksef::NotFoundError) { |err| expect(err.status).to eq(404) }
    end

    it "raises RateLimitError on 429 and surfaces retry-after" do
      stub_request(:post, SpecSupport.api_url("/auth/challenge"))
        .to_return(status: 429, body: "{}", headers: { "Retry-After" => "12", "Content-Type" => "application/json" })

      expect { connection.request(:post, "/auth/challenge") }
        .to raise_error(Ksef::RateLimitError) { |err|
          expect(err.status).to eq(429)
          expect(err.retry_after).to eq(12)
        }
    end

    it "raises ServerError on 500" do
      stub_request(:get, SpecSupport.api_url("/auth/sessions/current"))
        .to_return(status: 500, body: "{}", headers: { "Content-Type" => "application/json" })

      expect { connection.request(:get, "/auth/sessions/current") }
        .to raise_error(Ksef::ServerError)
    end

    it "raises ClientError on 4xx otherwise" do
      stub_request(:get, SpecSupport.api_url("/auth/sessions/current"))
        .to_return(status: 418, body: "{}", headers: { "Content-Type" => "application/json" })

      expect { connection.request(:get, "/auth/sessions/current") }
        .to raise_error(Ksef::ClientError)
    end

    it "parses RFC 7807 problem-details bodies" do
      stub_request(:get, SpecSupport.api_url("/auth/sessions/current"))
        .to_return(
          status: 403,
          body: { title: "Forbidden", status: 403, detail: "No permission" }.to_json,
          headers: { "Content-Type" => "application/problem+json" }
        )

      expect { connection.request(:get, "/auth/sessions/current") }
        .to raise_error(Ksef::AuthError, /No permission/)
    end
  end

  describe "request building" do
    it "sets bearer token when supplied" do
      stub = stub_request(:get, SpecSupport.api_url("/auth/sessions/current"))
             .with(headers: { "Authorization" => "Bearer abc" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      connection.request(:get, "/auth/sessions/current", bearer_token: "abc")
      expect(stub).to have_been_requested
    end

    it "encodes hash bodies as JSON" do
      stub = stub_request(:post, SpecSupport.api_url("/auth/ksef-token"))
             .with(body: { foo: "bar" }.to_json,
                   headers: { "Content-Type" => "application/json" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      connection.request(:post, "/auth/ksef-token", body: { foo: "bar" })
      expect(stub).to have_been_requested
    end

    it "passes string bodies through untouched" do
      stub = stub_request(:post, SpecSupport.api_url("/auth/xades-signature"))
             .with(body: "<xml/>")
             .to_return(status: 202, body: "{}", headers: { "Content-Type" => "application/json" })

      connection.request(:post, "/auth/xades-signature", body: "<xml/>",
                                                          headers: { "Content-Type" => "application/xml" })
      expect(stub).to have_been_requested
    end

    it "merges query params" do
      stub = stub_request(:post, "#{SpecSupport.api_url("/invoices/query/metadata")}?pageSize=50")
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      connection.request(:post, "/invoices/query/metadata", query: { "pageSize" => 50 })
      expect(stub).to have_been_requested
    end
  end

  describe "logger configuration" do
    it "wires Faraday's logger middleware when a logger is set" do
      config = Ksef::Configuration.new
      config.logger = Logger.new(IO::NULL)
      stub_request(:get, SpecSupport.api_url("/auth/sessions/current"))
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      described_class.new(config).request(:get, "/auth/sessions/current")
      expect(WebMock).to have_requested(:get, SpecSupport.api_url("/auth/sessions/current"))
    end
  end

  describe "Retry-After parsing" do
    it "returns nil for non-integer retry-after values" do
      stub_request(:post, SpecSupport.api_url("/auth/challenge"))
        .to_return(status: 429, body: "{}", headers: { "Retry-After" => "not-a-number" })

      expect { connection.request(:post, "/auth/challenge") }
        .to raise_error(Ksef::RateLimitError) { |err| expect(err.retry_after).to be_nil }
    end
  end

  describe ".parse_json" do
    it "returns {} for empty bodies" do
      response = instance_double(Faraday::Response, body: nil)
      expect(described_class.parse_json(response)).to eq({})
    end

    it "returns {} on malformed JSON" do
      response = instance_double(Faraday::Response, body: "not json")
      expect(described_class.parse_json(response)).to eq({})
    end

    it "parses well-formed JSON" do
      response = instance_double(Faraday::Response, body: '{"foo":1}')
      expect(described_class.parse_json(response)).to eq("foo" => 1)
    end
  end
end
