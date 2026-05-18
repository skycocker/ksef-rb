# frozen_string_literal: true

require "openssl"
require "base64"

module Ksef
  module Internal
    # Encrypts a KSeF integration token for the `/auth/ksef-token` endpoint.
    #
    # Per the KSeF 2.0 docs:
    #   - The payload is `"{token}|{timestampMs}"`, where `timestampMs` comes
    #     from the `/auth/challenge` response.
    #   - Encryption is RSA-OAEP with SHA-256 (and MGF1-SHA-256).
    #   - The ciphertext is Base64-encoded for transport.
    #
    # The PEM-encoded RSA public key is supplied by the caller (typically
    # fetched from `/security/public-key-certificates`).
    module TokenEncryptor
      module_function

      # @param token         [String] raw KSeF integration token
      # @param timestamp_ms  [Integer] timestamp from the challenge response
      # @param public_key_pem [String] PEM-encoded RSA public key
      # @return [String] Base64-encoded ciphertext
      def encrypt(token:, timestamp_ms:, public_key_pem:)
        plaintext = "#{token}|#{timestamp_ms}"
        key = OpenSSL::PKey::RSA.new(public_key_pem)
        ciphertext = key.encrypt(
          plaintext,
          rsa_padding_mode: "oaep",
          rsa_oaep_md:      "sha256",
          rsa_mgf1_md:      "sha256"
        )
        Base64.strict_encode64(ciphertext)
      end

      # Convenience wrapper that handles raw DER-encoded (base64) keys returned
      # by the public-key endpoint, falling back to PEM if the input already
      # contains BEGIN markers.
      def normalize_public_key(raw)
        return raw if raw.to_s.include?("BEGIN")

        der = Base64.decode64(raw.to_s)
        OpenSSL::PKey::RSA.new(der).to_pem
      end
    end
  end
end
