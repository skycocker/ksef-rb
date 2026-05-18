# frozen_string_literal: true

require_relative "ksef/version"
require_relative "ksef/errors"
require_relative "ksef/configuration"
require_relative "ksef/credentials/token"
require_relative "ksef/credentials/certificate"
require_relative "ksef/internal/connection"
require_relative "ksef/internal/token_encryptor"
require_relative "ksef/session"
require_relative "ksef/sessions"
require_relative "ksef/invoice_header"
require_relative "ksef/invoices"
require_relative "ksef/client"

# Ruby client for the Polish KSeF 2.0 (Krajowy System e-Faktur) API.
#
# @example Global configuration
#   Ksef.configure do |c|
#     c.environment = :test
#     c.user_agent  = "Pro Bau / ksef-rb #{Ksef::VERSION}"
#   end
module Ksef
  class << self
    # @return [Ksef::Configuration]
    def configuration
      @configuration ||= Configuration.new
    end

    # Yields the singleton {Configuration} for in-place mutation.
    def configure
      yield(configuration)
      configuration
    end

    # Resets the global configuration (primarily for tests).
    # @api private
    def reset_configuration!
      @configuration = Configuration.new
    end
  end

  # Namespace for implementation details. Anything under {Ksef::Internal} is
  # not part of the supported public API and may change without notice.
  module Internal; end
end
