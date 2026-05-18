# frozen_string_literal: true

module Ksef
  module Credentials
    # Certificate-based credential (qualified seal / XAdES signature flow).
    #
    # @note Stub for v0.1.0 — interactive sessions backed by a qualified seal
    #   require XAdES-signed XML which is out of scope for this release. The
    #   class is here so the public API shape doesn't shift when we land it.
    class Certificate
      def initialize(*)
        raise NotImplementedError,
              "Certificate-based authentication is not implemented in ksef-rb v#{Ksef::VERSION}. " \
              "Use Ksef::Credentials::Token for now; tracked for a future release."
      end
    end
  end
end
