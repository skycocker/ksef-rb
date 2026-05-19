# frozen_string_literal: true

# Bundler's default for `gem "ksef-rb"` is `require "ksef-rb"`. This shim
# makes that resolve to the canonical entry point without forcing every
# consumer to add `, require: "ksef"`.
require_relative "ksef"
