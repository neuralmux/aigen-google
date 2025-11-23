# frozen_string_literal: true

RSpec.describe Aigen::Google do
  after do
    # Reset configuration after each test
    described_class.configuration = nil
  end

  it "has a version number" do
    expect(Aigen::Google.gem_version).not_to be_nil
  end

  describe ".configure" do
    it "yields configuration block" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(Aigen::Google::Configuration)
    end

    it "sets configuration values via block" do
      described_class.configure do |config|
        config.api_key = "test-key"
        config.default_model = "gemini-pro-vision"
        config.timeout = 60
      end

      expect(described_class.configuration.api_key).to eq("test-key")
      expect(described_class.configuration.default_model).to eq("gemini-pro-vision")
      expect(described_class.configuration.timeout).to eq(60)
    end

    it "returns configuration object" do
      config = described_class.configure do |c|
        c.api_key = "test-key"
      end

      expect(config).to be_a(Aigen::Google::Configuration)
      expect(config.api_key).to eq("test-key")
    end

    it "creates configuration if it doesn't exist" do
      expect(described_class.configuration).to be_nil

      described_class.configure do |config|
        config.api_key = "test-key"
      end

      expect(described_class.configuration).to be_a(Aigen::Google::Configuration)
    end

    it "reuses existing configuration" do
      first_config = described_class.configure do |config|
        config.api_key = "first-key"
      end

      second_config = described_class.configure do |config|
        config.default_model = "gemini-pro-vision"
      end

      expect(first_config.object_id).to eq(second_config.object_id)
      expect(described_class.configuration.api_key).to eq("first-key")
      expect(described_class.configuration.default_model).to eq("gemini-pro-vision")
    end
  end

  describe ".configuration" do
    it "returns nil when not configured" do
      expect(described_class.configuration).to be_nil
    end

    it "returns configuration after configure is called" do
      described_class.configure { |c| c.api_key = "test" }

      expect(described_class.configuration).to be_a(Aigen::Google::Configuration)
    end
  end
end
