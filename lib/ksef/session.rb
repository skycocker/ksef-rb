# frozen_string_literal: true

module Ksef
  # An open authenticated session against the KSeF API.
  #
  # Holds the access/refresh tokens minted by `/auth/token/redeem` together
  # with the authentication operation's reference number. Instances are
  # produced by {Ksef::Sessions#open} (or {#with_interactive}) and consumed
  # by resource classes through {Ksef::Client#current_session}.
  class Session
    attr_reader :reference_number,
                :access_token, :access_token_valid_until,
                :refresh_token, :refresh_token_valid_until

    def initialize(reference_number:, access_token:, refresh_token:,
                   access_token_valid_until: nil, refresh_token_valid_until: nil)
      @reference_number          = reference_number
      @access_token              = access_token
      @refresh_token             = refresh_token
      @access_token_valid_until  = access_token_valid_until
      @refresh_token_valid_until = refresh_token_valid_until
      @terminated                = false
    end

    def terminated?
      @terminated
    end

    # Marks the session as closed locally. Network teardown is performed by
    # {Ksef::Sessions#terminate}.
    def mark_terminated!
      @terminated = true
    end

    def to_s
      "#<Ksef::Session reference_number=#{@reference_number.inspect} " \
        "terminated=#{@terminated}>"
    end
    alias inspect to_s
  end
end
