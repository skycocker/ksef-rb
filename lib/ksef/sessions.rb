# frozen_string_literal: true

module Ksef
  # Manages the KSeF interactive session lifecycle:
  #
  #   1. `POST /auth/challenge`        → challenge + timestamp
  #   2. encrypt the integration token with the KSeF public RSA key
  #   3. `POST /auth/ksef-token`       → authentication operation token
  #   4. poll `GET  /auth/{ref}`       → wait for status = success
  #   5. `POST /auth/token/redeem`     → access + refresh tokens
  #   6. on close: `DELETE /auth/sessions/current`
  #
  # The most common entry point is {#with_interactive}, which sets up the
  # session, yields it to the caller's block, and tears it down on exit.
  class Sessions
    AUTH_SUCCESS_STATUS = 200
    AUTH_PENDING_STATUS = 100
    DEFAULT_POLL_INTERVAL = 1.0
    DEFAULT_POLL_TIMEOUT  = 60

    def initialize(client)
      @client = client
    end

    # Opens a session, yields it, and ensures it is terminated.
    #
    # @yield  [Ksef::Session]
    # @return whatever the block returns
    def with_interactive(**opts)
      session = open(**opts)
      @client.current_session = session
      begin
        yield session
      ensure
        terminate(session) unless session.terminated?
        @client.current_session = nil
      end
    end

    # Acquires a new authenticated session. Callers can then attach it via
    # {Ksef::Client#current_session=} if they prefer manual management.
    #
    # @param poll_interval [Float]   seconds between status polls
    # @param poll_timeout  [Integer] total seconds to wait for auth completion
    # @return [Ksef::Session]
    def open(poll_interval: DEFAULT_POLL_INTERVAL, poll_timeout: DEFAULT_POLL_TIMEOUT)
      credentials = @client.credentials
      case credentials
      when Credentials::Token
        open_with_token(credentials, poll_interval: poll_interval, poll_timeout: poll_timeout)
      else
        raise NotImplementedError,
              "Only Ksef::Credentials::Token is supported in v#{Ksef::VERSION}"
      end
    end

    # Closes the session by calling `DELETE /auth/sessions/current`.
    def terminate(session)
      return if session.terminated?

      @client.connection.request(
        :delete,
        "/auth/sessions/current",
        bearer_token: session.access_token
      )
      session.mark_terminated!
      session
    end

    # Fetches the freshest public-key certificate suitable for token encryption.
    # Cached for the lifetime of the Sessions instance.
    def public_key_for_token_encryption
      @public_key_for_token_encryption ||= fetch_public_key
    end

    private

    def open_with_token(token_credentials, poll_interval:, poll_timeout:)
      challenge_data = fetch_challenge
      key_info       = public_key_for_token_encryption

      encrypted = Internal::TokenEncryptor.encrypt(
        token:          token_credentials.value,
        timestamp_ms:   challenge_data.fetch("timestampMs"),
        public_key_pem: key_info[:pem]
      )

      init_response = init_with_token(
        challenge:       challenge_data.fetch("challenge"),
        encrypted_token: encrypted,
        public_key_id:   key_info[:id]
      )

      reference_number     = init_response.fetch("referenceNumber")
      authentication_token = init_response.fetch("authenticationToken").fetch("token")

      wait_for_authentication(reference_number, authentication_token,
                              poll_interval: poll_interval, poll_timeout: poll_timeout)

      redeem_tokens(reference_number, authentication_token)
    end

    def fetch_challenge
      response = @client.connection.request(:post, "/auth/challenge")
      Internal::Connection.parse_json(response)
    end

    def init_with_token(challenge:, encrypted_token:, public_key_id:)
      body = {
        "challenge"         => challenge,
        "contextIdentifier" => { "type" => "Nip", "value" => @client.nip },
        "encryptedToken"    => encrypted_token
      }
      body["publicKeyId"] = public_key_id if public_key_id

      response = @client.connection.request(:post, "/auth/ksef-token", body: body)
      Internal::Connection.parse_json(response)
    end

    def wait_for_authentication(reference_number, authentication_token,
                                poll_interval:, poll_timeout:)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + poll_timeout

      loop do
        response = @client.connection.request(
          :get,
          "/auth/#{reference_number}",
          bearer_token: authentication_token
        )
        body   = Internal::Connection.parse_json(response)
        status = body.dig("status", "code")

        return if status == AUTH_SUCCESS_STATUS

        if status && status != AUTH_PENDING_STATUS
          raise AuthError.new(
            "KSeF authentication failed: #{body.dig("status", "description")}",
            status: status,
            body:   body,
            code:   status
          )
        end

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise AuthError, "Timed out waiting for KSeF authentication (ref=#{reference_number})"
        end

        sleep poll_interval
      end
    end

    def redeem_tokens(reference_number, authentication_token)
      response = @client.connection.request(
        :post,
        "/auth/token/redeem",
        bearer_token: authentication_token
      )
      body = Internal::Connection.parse_json(response)

      access  = body.fetch("accessToken")
      refresh = body.fetch("refreshToken")

      Session.new(
        reference_number:          reference_number,
        access_token:              access.fetch("token"),
        access_token_valid_until:  access["validUntil"],
        refresh_token:             refresh.fetch("token"),
        refresh_token_valid_until: refresh["validUntil"]
      )
    end

    def fetch_public_key
      response = @client.connection.request(:get, "/security/public-key-certificates")
      list = Internal::Connection.parse_json(response)
      list = list["items"] if list.is_a?(Hash) && list.key?("items")

      candidate = Array(list).find do |entry|
        Array(entry["usage"]).include?("KsefTokenEncryption")
      end || Array(list).first

      raise AuthError, "No public-key certificate available for KSeF token encryption" if candidate.nil?

      {
        id:  candidate["publicKeyId"],
        pem: Internal::TokenEncryptor.normalize_public_key(candidate["certificate"])
      }
    end
  end
end
