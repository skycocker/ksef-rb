# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  enable_coverage :line
end

require "logger"
require "webmock/rspec"
WebMock.disable_net_connect!(allow_localhost: true)

require "vcr"
VCR.configure do |config|
  config.cassette_library_dir = File.expand_path("vcr_cassettes", __dir__)
  config.hook_into :webmock
  config.default_cassette_options = {
    record:           ENV["KSEF_RECORD"] == "true" ? :new_episodes : :none,
    match_requests_on: %i[method uri body],
    allow_playback_repeats: true
  }
  config.filter_sensitive_data("<KSEF_TOKEN>") { ENV["KSEF_TOKEN"] }
end

# `hook_into :webmock` flips WebMock's net-connect setting; reassert the lock
# so unmatched specs don't accidentally reach the live API.
VCR.turn_off!(ignore_cassettes: true)
WebMock.disable_net_connect!(allow_localhost: true)

require "ksef"

# Test-only RSA key used to encrypt the `/auth/ksef-token` payload in specs.
# Generated once per process so cassettes recorded with one run remain replayable.
TEST_RSA_KEY = OpenSSL::PKey::RSA.generate(2048)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.warnings = false
  config.order = :random
  Kernel.srand(config.seed)

  config.before do
    Ksef.reset_configuration!
  end

  # Opt-in VCR. Tag examples or groups with `:vcr` to enable replay. The
  # cassette name and options come from `vcr: { ... }` metadata on the
  # example, mimicking the shape VCR's auto-metadata integration exposes.
  config.around(:each, :vcr) do |example|
    metadata = example.metadata[:vcr]
    metadata = {} unless metadata.is_a?(Hash)
    name = metadata[:cassette_name] ||
           example.full_description.gsub(/\W+/, "_").downcase
    options = metadata.reject { |k, _| k == :cassette_name }
    VCR.turn_on!
    begin
      VCR.use_cassette(name, options) { example.run }
    ensure
      VCR.turn_off!(ignore_cassettes: true)
    end
  end
end

# Test helpers shared across specs.
module SpecSupport
  module_function

  # Builds the `Ksef::Client` used by most specs.
  def build_client(nip: "1234567890", token: "test-token")
    Ksef::Client.new(
      nip:         nip,
      credentials: Ksef::Credentials::Token.new(token)
    )
  end

  # Returns the configured base URL prefix for stub matchers.
  def api_url(path)
    "https://api-test.ksef.mf.gov.pl/v2#{path}"
  end

  # JSON body used to stub `/security/public-key-certificates`.
  def public_key_certificates_body
    [
      {
        "certificate"    => Base64.strict_encode64(TEST_RSA_KEY.public_key.to_der),
        "certificateId"  => "test-cert-id",
        "publicKeyId"    => "test-public-key-id",
        "validFrom"      => "2024-01-01T00:00:00Z",
        "validTo"        => "2099-01-01T00:00:00Z",
        "usage"          => ["KsefTokenEncryption"]
      }
    ]
  end

  # Shared challenge body matching the OpenAPI example.
  def challenge_body
    {
      "challenge"   => "20250514-CR-226FB7B000-3ACF9BE4C0-10",
      "timestamp"   => "2025-05-14T12:23:56Z",
      "timestampMs" => 1_747_229_019_000,
      "clientIp"    => "127.0.0.1"
    }
  end

  def auth_init_body
    {
      "referenceNumber"     => "20250514-AU-2DFC46C000-3AC6D5877F-D4",
      "authenticationToken" => {
        "token"      => "auth-op-jwt",
        "validUntil" => "2025-05-14T13:23:56Z"
      }
    }
  end

  def auth_status_body(code: 200, description: "Uwierzytelnianie zakończone sukcesem")
    {
      "startDate"            => "2025-05-14T12:23:00Z",
      "authenticationMethod" => "Token",
      "status"               => { "code" => code, "description" => description }
    }
  end

  def redeem_body
    {
      "accessToken"  => { "token" => "access-jwt",  "validUntil" => "2025-05-14T14:23:56Z" },
      "refreshToken" => { "token" => "refresh-jwt", "validUntil" => "2025-05-15T12:23:56Z" }
    }
  end
end

RSpec.configure do |config|
  config.include SpecSupport
end
