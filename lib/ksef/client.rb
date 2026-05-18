# frozen_string_literal: true

module Ksef
  # Main entry point for the KSeF API.
  #
  # @example
  #   client = Ksef::Client.new(
  #     nip: "1234567890",
  #     credentials: Ksef::Credentials::Token.new(ENV.fetch("KSEF_TOKEN"))
  #   )
  #
  #   client.sessions.with_interactive do |session|
  #     headers = client.invoices.query(
  #       subject_type: :recipient,
  #       date_from: Time.now.utc - (7 * 24 * 3600),
  #       date_to:   Time.now.utc
  #     )
  #     xml = client.invoices.fetch_xml(headers.first.ksef_reference_number)
  #   end
  class Client
    attr_reader :nip, :credentials, :configuration
    attr_accessor :current_session

    def initialize(nip:, credentials:, configuration: nil)
      raise ConfigurationError, "nip cannot be blank" if nip.nil? || nip.to_s.empty?

      @nip             = nip.to_s
      @credentials     = credentials
      @configuration   = configuration || Ksef.configuration.dup
      @current_session = nil
    end

    # Lazily-built HTTP connection. Public so the resource classes can share
    # it; not part of the supported public surface — treat as internal.
    def connection
      @connection ||= Internal::Connection.new(@configuration)
    end

    def sessions
      @sessions ||= Sessions.new(self)
    end

    def invoices
      @invoices ||= Invoices.new(self)
    end
  end
end
