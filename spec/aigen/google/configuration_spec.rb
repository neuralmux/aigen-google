# frozen_string_literal: true

RSpec.describe Aigen::Google::Configuration do
  describe "#initialize" do
    it "sets default values" do
      config = described_class.new

      expect(config.default_model).to eq("gemini-pro")
      expect(config.timeout).to eq(30)
      expect(config.retry_count).to eq(3)
    end

    it "reads API key from environment variable" do
      ENV["GOOGLE_API_KEY"] = "test-key-from-env"
      config = described_class.new

      expect(config.api_key).to eq("test-key-from-env")
    ensure
      ENV.delete("GOOGLE_API_KEY")
    end
  end

  describe "#validate!" do
    it "raises ConfigurationError when API key is nil" do
      config = described_class.new
      config.api_key = nil

      expect { config.validate! }.to raise_error(Aigen::Google::ConfigurationError, /API key is required/)
    end

    it "raises ConfigurationError when API key is empty" do
      config = described_class.new
      config.api_key = ""

      expect { config.validate! }.to raise_error(Aigen::Google::ConfigurationError, /API key is required/)
    end

    it "does not raise error when API key is present" do
      config = described_class.new
      config.api_key = "valid-key"

      expect { config.validate! }.not_to raise_error
    end
  end

  describe "attribute accessors" do
    it "allows setting and getting configuration values" do
      config = described_class.new

      config.api_key = "custom-key"
      config.default_model = "gemini-pro-vision"
      config.timeout = 60
      config.retry_count = 5

      expect(config.api_key).to eq("custom-key")
      expect(config.default_model).to eq("gemini-pro-vision")
      expect(config.timeout).to eq(60)
      expect(config.retry_count).to eq(5)
    end
  end
end
