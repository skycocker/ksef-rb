# frozen_string_literal: true

RSpec.describe Ksef::Internal::TokenEncryptor do
  let(:key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:pem) { key.public_key.to_pem }

  describe ".encrypt" do
    it "produces a Base64-encoded RSA-OAEP/SHA-256 payload" do
      ciphertext = described_class.encrypt(
        token:          "my-token",
        timestamp_ms:   1_700_000_000_000,
        public_key_pem: pem
      )

      raw = Base64.strict_decode64(ciphertext)
      plaintext = key.decrypt(raw, rsa_padding_mode: "oaep", rsa_oaep_md: "sha256", rsa_mgf1_md: "sha256")
      expect(plaintext).to eq("my-token|1700000000000")
    end

    it "raises if the key material is invalid" do
      expect do
        described_class.encrypt(token: "x", timestamp_ms: 1, public_key_pem: "not a key")
      end.to raise_error(OpenSSL::PKey::PKeyError)
    end
  end

  describe ".normalize_public_key" do
    it "returns PEM unchanged" do
      expect(described_class.normalize_public_key(pem)).to eq(pem)
    end

    it "converts base64-encoded bare-key DER to PEM" do
      der = key.public_key.to_der
      normalized = described_class.normalize_public_key(Base64.strict_encode64(der))
      expect(normalized).to include("BEGIN PUBLIC KEY")
    end

    # Regression: KSeF's /security/public-key-certificates returns a DER X.509
    # certificate, not a bare SPKI. We must parse it as a cert and extract the
    # public key before encryption.
    it "extracts the public key from a base64-encoded DER X.509 certificate" do
      cert = OpenSSL::X509::Certificate.new
      cert.version    = 2
      cert.serial     = 42
      cert.subject    = OpenSSL::X509::Name.parse("/CN=ksef-cert")
      cert.issuer     = cert.subject
      cert.public_key = key.public_key
      cert.not_before = Time.utc(2024, 1, 1)
      cert.not_after  = Time.utc(2099, 1, 1)
      cert.sign(key, OpenSSL::Digest.new("SHA256"))

      normalized = described_class.normalize_public_key(Base64.strict_encode64(cert.to_der))

      expect(normalized).to include("BEGIN PUBLIC KEY")
      # The extracted key must round-trip a real encryption against the cert's key.
      ciphertext = described_class.encrypt(
        token: "abc", timestamp_ms: 1, public_key_pem: normalized
      )
      raw = Base64.strict_decode64(ciphertext)
      plaintext = key.decrypt(raw, rsa_padding_mode: "oaep",
                                   rsa_oaep_md: "sha256", rsa_mgf1_md: "sha256")
      expect(plaintext).to eq("abc|1")
    end
  end
end
