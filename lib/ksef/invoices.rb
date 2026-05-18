# frozen_string_literal: true

module Ksef
  # Inbound-invoice retrieval. All operations require an open session
  # (see {Ksef::Sessions#with_interactive}).
  class Invoices
    SUBJECT_TYPE_MAP = {
      issuer:             "Subject1",
      seller:             "Subject1",
      recipient:          "Subject2",
      buyer:              "Subject2",
      third:              "Subject3",
      subject_authorized: "SubjectAuthorized"
    }.freeze

    DATE_TYPE_MAP = {
      issue:             "Issue",
      invoicing:         "Invoicing",
      permanent_storage: "PermanentStorage"
    }.freeze

    DEFAULT_PAGE_SIZE = 100

    def initialize(client)
      @client = client
    end

    # Queries invoice metadata.
    #
    # @param subject_type [Symbol] :recipient (default), :issuer, :third, :subject_authorized
    # @param date_from    [Time, DateTime, String] start of date range (inclusive)
    # @param date_to      [Time, DateTime, String, nil] end of date range, defaults to "now"
    # @param date_type    [Symbol] :permanent_storage (default), :invoicing, :issue
    # @param page_size    [Integer] 10..250
    # @param page_offset  [Integer]
    # @param sort_order   [String]  "Asc" (default) or "Desc"
    # @param extra_filters [Hash]   additional InvoiceQueryFilters fields, passed through verbatim
    # @return [Array<Ksef::InvoiceHeader>]
    def query(subject_type: :recipient, date_from:, date_to: nil, date_type: :permanent_storage,
              page_size: DEFAULT_PAGE_SIZE, page_offset: 0, sort_order: "Asc", extra_filters: {})
      filters = {
        "subjectType" => translate_subject(subject_type),
        "dateRange"   => {
          "dateType" => translate_date_type(date_type),
          "from"     => to_iso8601(date_from)
        }
      }
      filters["dateRange"]["to"] = to_iso8601(date_to) if date_to
      filters.merge!(stringify_keys(extra_filters))

      response = require_session.connection.request(
        :post,
        "/invoices/query/metadata",
        body:         filters,
        query:        { "pageOffset" => page_offset, "pageSize" => page_size, "sortOrder" => sort_order },
        bearer_token: current_access_token
      )
      body = Internal::Connection.parse_json(response)
      Array(body["invoices"]).map { |raw| InvoiceHeader.new(raw) }
    end

    # Fetches the raw FA(3) XML for the invoice identified by `ksef_reference_number`.
    # @return [String] XML document bytes
    def fetch_xml(ksef_reference_number)
      raise ArgumentError, "ksef_reference_number cannot be blank" if blank?(ksef_reference_number)

      response = require_session.connection.request(
        :get,
        "/invoices/ksef/#{ksef_reference_number}",
        headers:      { "Accept" => "application/xml" },
        bearer_token: current_access_token
      )
      response.body.to_s
    end

    # @note Not implemented in v0.1.0.
    #
    # KSeF 2.0 does not currently expose a server-rendered PDF/HTML
    # visualisation of an invoice through the public API. The visualisation
    # is produced client-side from the FA(3) XML using the official XSLT
    # (`wizualizacja-faktury_v3-0.xsl`) shipped with the ksef-docs repo, or
    # by combining the XML with a PDF rendering library (e.g. WeasyPrint,
    # Puppeteer + the official HTML preview).
    #
    # @param _ksef_reference_number [String]
    def fetch_visualisation(_ksef_reference_number)
      raise NotImplementedError, <<~MSG
        KSeF 2.0 has no public endpoint that returns a PDF visualisation of an
        invoice. Generate it client-side from the XML retrieved via #fetch_xml
        using the official XSLT (wizualizacja-faktury_v3-0.xsl) and your
        preferred renderer. Tracked for a future ksef-rb release.
      MSG
    end

    # @note Not implemented in v0.1.0.
    #
    # UPO (Urzędowe Poświadczenie Odbioru) downloads are scoped to the
    # *sender* sessions that produced them (see `GET /sessions/{ref}/upo/...`).
    # Recipient-side UPO retrieval is not available in v0.1.0; outbound
    # issuance is also stubbed.
    def fetch_upo(_ksef_reference_number)
      raise NotImplementedError,
            "UPO download is not implemented in ksef-rb v#{Ksef::VERSION}. " \
            "Tracked alongside outbound invoice issuance."
    end

    private

    def translate_subject(symbol)
      SUBJECT_TYPE_MAP.fetch(symbol) do
        raise ArgumentError,
              "Unknown subject_type #{symbol.inspect}. " \
              "Expected one of: #{SUBJECT_TYPE_MAP.keys.inspect}"
      end
    end

    def translate_date_type(symbol)
      DATE_TYPE_MAP.fetch(symbol) do
        raise ArgumentError,
              "Unknown date_type #{symbol.inspect}. " \
              "Expected one of: #{DATE_TYPE_MAP.keys.inspect}"
      end
    end

    def to_iso8601(value)
      case value
      when nil    then nil
      when String then value
      when Date   then value.iso8601
      else value.utc.iso8601
      end
    end

    def stringify_keys(hash)
      hash.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
    end

    def require_session
      session = @client.current_session
      raise AuthError, "No active KSeF session. Call client.sessions.with_interactive { ... } first." if session.nil?
      raise AuthError, "Session #{session.reference_number} has been terminated." if session.terminated?

      @client
    end

    def current_access_token
      @client.current_session.access_token
    end

    def blank?(value)
      value.nil? || value.to_s.empty?
    end
  end
end
