# frozen_string_literal: true

require_relative "lib/ksef/version"

Gem::Specification.new do |spec|
  spec.name          = "ksef-rb"
  spec.version       = Ksef::VERSION
  spec.authors       = ["Michał Siwek"]
  spec.email         = ["michal.siwek@shape.care"]

  spec.summary       = "Ruby client for the Polish KSeF 2.0 (Krajowy System e-Faktur) API"
  spec.description   = "A Ruby client for the Polish National e-Invoicing System (KSeF 2.0). " \
                       "Supports the FA(3) schema, authentication, sessions, and inbound invoice retrieval."
  spec.homepage      = "https://github.com/skycocker/ksef-rb"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = spec.homepage
  spec.metadata["changelog_uri"]     = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"]   = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*.rb",
    "LICENSE.txt",
    "README.md",
    "CHANGELOG.md"
  ]
  spec.require_paths = ["lib"]
end
