# frozen_string_literal: true

require "date"
require "time"

module Ksef
  # Lightweight value object describing an invoice as returned by
  # `POST /invoices/query/metadata`. Built from a single element of the
  # `invoices` array in the API response.
  #
  # The object intentionally exposes a small, business-meaningful slice of the
  # full payload. The raw hash is preserved on {#raw} for advanced callers.
  class InvoiceHeader
    attr_reader :ksef_reference_number,
                :invoice_number,
                :issuer_nip, :issuer_name,
                :recipient_nip, :recipient_name,
                :issued_on, :acquired_at, :permanently_stored_at,
                :net_amount, :gross_amount, :vat_amount, :currency,
                :invoicing_mode, :invoice_type,
                :form_code, :form_schema_version,
                :self_invoicing, :has_attachment,
                :invoice_hash, :raw

      def initialize(raw)
        @raw = raw
        @ksef_reference_number = raw["ksefNumber"]
        @invoice_number        = raw["invoiceNumber"]
        @issuer_nip            = raw.dig("seller", "nip")
        @issuer_name           = raw.dig("seller", "name")
        @recipient_nip         = raw.dig("buyer", "identifier", "value")
        @recipient_name        = raw.dig("buyer", "name")
        @issued_on             = parse_date(raw["issueDate"])
        @acquired_at           = parse_time(raw["acquisitionDate"])
        @permanently_stored_at = parse_time(raw["permanentStorageDate"])
        @net_amount            = raw["netAmount"]
        @gross_amount          = raw["grossAmount"]
        @vat_amount            = raw["vatAmount"]
        @currency              = raw["currency"]
        @invoicing_mode        = raw["invoicingMode"]
        @invoice_type          = raw["invoiceType"]
        @form_code             = raw.dig("formCode", "value")
        @form_schema_version   = raw.dig("formCode", "schemaVersion")
        @self_invoicing        = raw["isSelfInvoicing"]
        @has_attachment        = raw["hasAttachment"]
        @invoice_hash          = raw["invoiceHash"]
      end

    def self_invoicing?
      @self_invoicing == true
    end

    def has_attachment?
      @has_attachment == true
    end

    private

    def parse_date(value)
      return if value.nil? || value.empty?

      Date.iso8601(value)
    rescue ArgumentError
      nil
    end

    def parse_time(value)
      return if value.nil? || value.empty?

      Time.iso8601(value)
    rescue ArgumentError
      nil
    end
  end
end
