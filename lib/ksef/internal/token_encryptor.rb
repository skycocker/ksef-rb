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

      # Normalizes whatever `/security/public-key-certificates` hands us into a
      # PEM-encoded RSA public key suitable for {.encrypt}.
      #
      # KSeF returns the `certificate` field as a base64-encoded DER X.509
      # certificate (not a bare public key), so we parse it as a cert first
      # and extract the SPKI. PEM-armored inputs and bare-key DER blobs are
      # also accepted as a courtesy.
      def normalize_public_key(raw)
        text = raw.to_s
        return text if text.include?("BEGIN")

        der = Base64.decode64(text)
        OpenSSL::X509::Certificate.new(der).public_key.to_pem
      rescue OpenSSL::X509::CertificateError
        OpenSSL::PKey::RSA.new(der).to_pem
      end
    end
  end
end
