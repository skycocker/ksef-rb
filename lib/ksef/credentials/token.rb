# frozen_string_literal: true

module Ksef
  module Credentials
    # A long-lived KSeF integration token, minted in the KSeF portal after
    # Profil Zaufany / qualified-seal login.
    #
    # The raw token value is treated as opaque; it is encrypted with the KSeF
    # public RSA key during the {Ksef::Sessions} init flow.
    class Token
      attr_reader :value

      def initialize(value)
        raise ConfigurationError, "Token value cannot be blank" if value.nil? || value.to_s.empty?

        @value = value.to_s
      end

      def type
        :token
      end

      def to_s
        "#<Ksef::Credentials::Token value=[REDACTED]>"
      end
      alias inspect to_s
    end
  end
end
