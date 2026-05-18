# frozen_string_literal: true

module Ksef
  # Base class for all KSeF gem errors.
  class Error < StandardError
    # The underlying HTTP status code, when applicable.
    attr_reader :status

    # The parsed error body returned by the API, when applicable.
    attr_reader :body

    # The KSeF-specific exception code, when surfaced in the body.
    attr_reader :code

    def initialize(message = nil, status: nil, body: nil, code: nil)
      super(message)
      @status = status
      @body = body
      @code = code
    end
  end

  # Raised when the API rejects authentication (401 / 403 or auth-status failure).
  class AuthError < Error; end

  # Raised when an upstream resource cannot be located (404 / invoice-not-found).
  class NotFoundError < Error; end

  # Raised on 4xx responses we don't otherwise classify.
  class ClientError < Error; end

  # Raised when the API returns 5xx.
  class ServerError < Error; end

  # Raised when the API returns 429. `retry_after` is in seconds when known.
  class RateLimitError < Error
    attr_reader :retry_after

    def initialize(message = nil, status: nil, body: nil, code: nil, retry_after: nil)
      super(message, status: status, body: body, code: code)
      @retry_after = retry_after
    end
  end

  # Raised when configuration is missing or invalid.
  class ConfigurationError < Error; end
end
