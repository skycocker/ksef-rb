# frozen_string_literal: true

require_relative "lib/ksef/version"

Gem::Specification.new do |spec|
  spec.name          = "ksef-rb"
  spec.version       = Ksef::VERSION
  spec.authors       = ["Michał Siwek"]
  spec.email         = ["michal.siwek@shape.care"]

  spec.summary       = "Ruby client for the Polish KSeF 2.0 (Krajowy System e-Faktur) API"
  spec.description   = <<~DESC
    A Ruby client for the Polish National e-Invoicing System (KSeF 2.0).
    Targets the FA(3) schema, supports token-based authentication, interactive
    sessions, and inbound invoice retrieval (metadata, XML, and visualisation).
    Pure Ruby with no Rails dependency.
  DESC
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

  spec.add_dependency "base64", "~> 0.2"
  spec.add_dependency "faraday", ">= 2.0", "< 3.0"
  spec.add_dependency "faraday-retry", ">= 2.0", "< 3.0"
  spec.add_dependency "nokogiri", ">= 1.15"
end
