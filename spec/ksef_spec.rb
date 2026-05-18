# frozen_string_literal: true

RSpec.describe Ksef do
  it "exposes a semantic version" do
    expect(Ksef::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  describe ".configure" do
    it "yields the singleton configuration and persists changes" do
      Ksef.configure do |c|
        c.environment = :production
        c.user_agent  = "test-ua"
      end

      expect(Ksef.configuration.environment).to eq(:production)
      expect(Ksef.configuration.user_agent).to eq("test-ua")
      expect(Ksef.configuration.resolved_base_url).to eq("https://api.ksef.mf.gov.pl/v2")
    end
  end

  describe ".reset_configuration!" do
    it "restores default configuration" do
      Ksef.configure { |c| c.environment = :production }
      Ksef.reset_configuration!
      expect(Ksef.configuration.environment).to eq(:test)
    end
  end
end
