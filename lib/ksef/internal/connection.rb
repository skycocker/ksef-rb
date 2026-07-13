# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module Ksef
  module Internal
    # Thin Faraday wrapper around the KSeF HTTP API.
    #
    # All response-shape parsing and error classification lives here so the
    # higher-level resource classes can treat the API as a typed boundary.
    class Connection
      RETRY_OPTIONS = {
        max:                 2,
        interval:            0.4,
        interval_randomness: 0.2,
        backoff_factor:      2,
        retry_statuses:      [502, 503, 504],
        methods:             %i[get head post delete put patch],
        # `Faraday::RetriableResponse` MUST stay in this list: faraday-retry
        # raises it internally to trigger a `retry_statuses` retry. Because we
        # override `exceptions` (rather than inheriting the middleware default,
        # which includes it), omitting it silently disables 502/503/504 retries
        # *and* leaks the raw synthetic exception past `check!` instead of
        # mapping it to a typed `Ksef::ServerError`.
        exceptions:          [
          Errno::ETIMEDOUT,
          Faraday::TimeoutError,
          Faraday::ConnectionFailed,
          Faraday::RetriableResponse
        ]
      }.freeze

      JSON_CONTENT_TYPE = "application/json"

      attr_reader :configuration

      def initialize(configuration)
        @configuration = configuration
      end

      # Issues an HTTP request and returns a `Faraday::Response`.
      #
      # @param method [Symbol] :get, :post, :delete, etc.
      # @param path   [String] path relative to `configuration.resolved_base_url`
      # @param body         [Object, nil] hash → JSON, String → raw body
      # @param headers      [Hash]
      # @param query        [Hash]
      # @param bearer_token [String, nil] sent as `Authorization: Bearer ...`
      # @return [Faraday::Response]
      def request(method, path, body: nil, headers: {}, query: {}, bearer_token: nil)
        response = http.run_request(method, expand_path(path), nil,
                                    build_headers(headers, bearer_token)) do |req|
          req.params.update(query) unless query.empty?
          assign_body(req, body)
        end
        check!(response)
        response
      end

      # Parses a JSON response body, returning `{}` on empty bodies.
      def self.parse_json(response)
        return {} if response.body.nil? || response.body.to_s.empty?

        JSON.parse(response.body)
      rescue JSON::ParserError
        {}
      end

      private

      # Resolves API-relative paths against the configured base URL. Faraday
      # treats `/auth/...` as absolute and would strip the `/v2` prefix; we
      # always pass a fully-qualified URL to avoid that pitfall.
      def expand_path(path)
        "#{configuration.resolved_base_url}#{path.start_with?("/") ? path : "/#{path}"}"
      end

      def http
        @http ||= Faraday.new do |conn|
          conn.request :retry, RETRY_OPTIONS
          conn.options.timeout      = configuration.timeout
          conn.options.open_timeout = configuration.open_timeout
          conn.headers["User-Agent"] = configuration.user_agent
          conn.headers["Accept"]     = JSON_CONTENT_TYPE
          if configuration.logger
            conn.response :logger, configuration.logger, headers: false, bodies: false
          end
          conn.adapter Faraday.default_adapter
        end
      end

      def build_headers(extra, bearer_token)
        headers = {}
        headers["Authorization"] = "Bearer #{bearer_token}" if bearer_token
        headers.merge(extra)
      end

      def assign_body(req, body)
        case body
        when nil
          # no body
        when String
          req.body = body
        else
          req.headers["Content-Type"] ||= JSON_CONTENT_TYPE
          req.body = JSON.dump(body)
        end
      end

      def check!(response)
        return if response.status.between?(200, 299)

        parsed = Connection.parse_json(response)
        code, message = extract_error_metadata(parsed)
        klass = error_class_for(response.status)

        raise build_error(klass, response, message, code, parsed)
      end

      def error_class_for(status)
        case status
        when 401, 403 then AuthError
        when 404      then NotFoundError
        when 429      then RateLimitError
        when 400..499 then ClientError
        when 500..599 then ServerError
        else Error
        end
      end

      def build_error(klass, response, message, code, body)
        text = message || "KSeF API error (HTTP #{response.status})"
        if klass == RateLimitError
          retry_after = parse_retry_after(response.headers["Retry-After"])
          klass.new(text, status: response.status, body: body, code: code, retry_after: retry_after)
        else
          klass.new(text, status: response.status, body: body, code: code)
        end
      end

      def parse_retry_after(value)
        return if value.nil?

        Integer(value)
      rescue ArgumentError, TypeError
        nil
      end

      # Handles both the legacy `ExceptionResponse` shape and the newer
      # RFC 7807 `application/problem+json` payload.
      def extract_error_metadata(parsed)
        return [nil, nil] unless parsed.is_a?(Hash)

        if parsed["exception"].is_a?(Hash)
          details = Array(parsed["exception"]["exceptionDetailList"]).first || {}
          [details["exceptionCode"], details["exceptionDescription"]]
        elsif parsed["title"] || parsed["detail"]
          [parsed["status"], parsed["detail"] || parsed["title"]]
        else
          [nil, nil]
        end
      end
    end
  end
end
