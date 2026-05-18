# frozen_string_literal: true

RSpec.describe Ksef::Sessions do
  let(:client) { SpecSupport.build_client }

  describe "#with_interactive happy path" do
    it "challenges, encrypts, redeems tokens, runs the block, and terminates" do
      stub_public_key
      stub_challenge
      stub_token_init
      stub_auth_status
      stub_redeem
      terminate_stub = stub_terminate

      yielded = nil
      client.sessions.with_interactive do |session|
        yielded = session
        expect(session.access_token).to eq("access-jwt")
        expect(session.refresh_token).to eq("refresh-jwt")
        expect(session.reference_number).to eq("20250514-AU-2DFC46C000-3AC6D5877F-D4")
        expect(client.current_session).to be(session)
      end

      expect(yielded.terminated?).to be(true)
      expect(client.current_session).to be_nil
      expect(terminate_stub).to have_been_requested
    end

    it "terminates the session even when the block raises" do
      stub_public_key
      stub_challenge
      stub_token_init
      stub_auth_status
      stub_redeem
      terminate_stub = stub_terminate

      expect do
        client.sessions.with_interactive { |_| raise "boom" }
      end.to raise_error(RuntimeError, "boom")

      expect(terminate_stub).to have_been_requested
    end
  end

  describe "auth error paths" do
    it "raises AuthError when the status check reports failure" do
      stub_public_key
      stub_challenge
      stub_token_init
      stub_auth_status(code: 450, description: "Nieprawidłowy token")
      # /auth/token/redeem should never be hit when status is fatal
      redeem_stub = stub_request(:post, SpecSupport.api_url("/auth/token/redeem"))

      expect { client.sessions.open(poll_interval: 0.0) }
        .to raise_error(Ksef::AuthError, /Nieprawidłowy token/)
      expect(redeem_stub).not_to have_been_requested
    end

    it "times out cleanly when authentication stays pending" do
      stub_public_key
      stub_challenge
      stub_token_init
      stub_request(:get, SpecSupport.api_url("/auth/20250514-AU-2DFC46C000-3AC6D5877F-D4"))
        .to_return(status: 200, body: SpecSupport.auth_status_body(code: 100, description: "Pending").to_json,
                   headers: { "Content-Type" => "application/json" })

      expect { client.sessions.open(poll_interval: 0.0, poll_timeout: 0) }
        .to raise_error(Ksef::AuthError, /Timed out/)
    end

    it "raises AuthError on 401 from the challenge endpoint" do
      stub_request(:post, SpecSupport.api_url("/auth/challenge"))
        .to_return(status: 401, body: "{}", headers: { "Content-Type" => "application/json" })

      expect { client.sessions.open }.to raise_error(Ksef::AuthError)
    end

    it "rejects non-token credentials" do
      bare = Object.new
      bad_client = Ksef::Client.new(nip: "1234567890", credentials: bare)
      expect { bad_client.sessions.open }.to raise_error(NotImplementedError)
    end
  end

  describe "#terminate" do
    it "is a no-op when the session is already terminated" do
      session = Ksef::Session.new(reference_number: "x", access_token: "a", refresh_token: "r")
      session.mark_terminated!
      expect(client.sessions.terminate(session)).to be_nil
    end
  end

  describe "#public_key_for_token_encryption" do
    it "raises if no certificate is returned" do
      stub_request(:get, SpecSupport.api_url("/security/public-key-certificates"))
        .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

      expect { client.sessions.public_key_for_token_encryption }
        .to raise_error(Ksef::AuthError, /No public-key certificate/)
    end
  end

  private

  def stub_public_key
    stub_request(:get, SpecSupport.api_url("/security/public-key-certificates"))
      .to_return(status: 200, body: SpecSupport.public_key_certificates_body.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def stub_challenge
    stub_request(:post, SpecSupport.api_url("/auth/challenge"))
      .to_return(status: 200, body: SpecSupport.challenge_body.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def stub_token_init
    stub_request(:post, SpecSupport.api_url("/auth/ksef-token"))
      .with do |req|
        body = JSON.parse(req.body)
        body["challenge"] == SpecSupport.challenge_body["challenge"] &&
          body["contextIdentifier"] == { "type" => "Nip", "value" => "1234567890" } &&
          !body["encryptedToken"].to_s.empty?
      end
      .to_return(status: 202, body: SpecSupport.auth_init_body.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def stub_auth_status(code: 200, description: "Uwierzytelnianie zakończone sukcesem")
    stub_request(:get, SpecSupport.api_url("/auth/20250514-AU-2DFC46C000-3AC6D5877F-D4"))
      .with(headers: { "Authorization" => "Bearer auth-op-jwt" })
      .to_return(status: 200, body: SpecSupport.auth_status_body(code: code, description: description).to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def stub_redeem
    stub_request(:post, SpecSupport.api_url("/auth/token/redeem"))
      .with(headers: { "Authorization" => "Bearer auth-op-jwt" })
      .to_return(status: 200, body: SpecSupport.redeem_body.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def stub_terminate
    stub_request(:delete, SpecSupport.api_url("/auth/sessions/current"))
      .with(headers: { "Authorization" => "Bearer access-jwt" })
      .to_return(status: 204, body: "")
  end
end
