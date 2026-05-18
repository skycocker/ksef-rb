# frozen_string_literal: true

module Ksef
  # Global gem configuration. Set via `Ksef.configure { |c| ... }`.
  #
  # Mutable defaults are exposed so callers can build a per-client
  # `Ksef::Client` override without touching the global state.
  class Configuration
    # Maps environment symbol → base URL.
    ENVIRONMENTS = {
      test:       "https://api-test.ksef.mf.gov.pl",
      demo:       "https://api-demo.ksef.mf.gov.pl",
      production: "https://api.ksef.mf.gov.pl"
    }.freeze

    DEFAULT_API_VERSION = "v2"

    attr_accessor :environment, :user_agent, :timeout, :open_timeout,
                  :api_version, :base_url, :logger

    def initialize
      @environment  = :test
      @user_agent   = "ksef-rb/#{Ksef::VERSION}"
      @timeout      = 30
      @open_timeout = 10
      @api_version  = DEFAULT_API_VERSION
      @base_url     = nil
      @logger       = nil
    end

    # Returns the effective base URL for the configured environment, including
    # the `/v2` (or whatever) API version path.
    def resolved_base_url
      root = @base_url || ENVIRONMENTS.fetch(@environment) do
        raise ConfigurationError, "Unknown KSeF environment: #{@environment.inspect}"
      end
      "#{root.chomp("/")}/#{@api_version}"
    end
  end
end
