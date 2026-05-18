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

    it "converts base64-encoded DER to PEM" do
      der = key.public_key.to_der
      normalized = described_class.normalize_public_key(Base64.strict_encode64(der))
      expect(normalized).to include("BEGIN PUBLIC KEY")
    end
  end
end
