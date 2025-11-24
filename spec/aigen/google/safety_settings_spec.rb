# frozen_string_literal: true

RSpec.describe Aigen::Google::SafetySettings do
  describe "constants" do
    it "defines harm category constants" do
      expect(described_class::HARM_CATEGORY_HATE_SPEECH).to eq("HARM_CATEGORY_HATE_SPEECH")
      expect(described_class::HARM_CATEGORY_DANGEROUS_CONTENT).to eq("HARM_CATEGORY_DANGEROUS_CONTENT")
      expect(described_class::HARM_CATEGORY_HARASSMENT).to eq("HARM_CATEGORY_HARASSMENT")
      expect(described_class::HARM_CATEGORY_SEXUALLY_EXPLICIT).to eq("HARM_CATEGORY_SEXUALLY_EXPLICIT")
    end

    it "defines threshold constants" do
      expect(described_class::BLOCK_NONE).to eq("BLOCK_NONE")
      expect(described_class::BLOCK_LOW_AND_ABOVE).to eq("BLOCK_LOW_AND_ABOVE")
      expect(described_class::BLOCK_MEDIUM_AND_ABOVE).to eq("BLOCK_MEDIUM_AND_ABOVE")
      expect(described_class::BLOCK_ONLY_HIGH).to eq("BLOCK_ONLY_HIGH")
    end
  end

  describe ".default" do
    it "returns default settings array" do
      defaults = described_class.default

      expect(defaults).to be_an(Array)
      expect(defaults.length).to eq(4)
    end

    it "sets BLOCK_MEDIUM_AND_ABOVE for all categories" do
      defaults = described_class.default

      defaults.each do |setting|
        expect(setting[:threshold]).to eq(described_class::BLOCK_MEDIUM_AND_ABOVE)
      end
    end

    it "includes all harm categories" do
      defaults = described_class.default
      categories = defaults.map { |s| s[:category] }

      expect(categories).to include(described_class::HARM_CATEGORY_HATE_SPEECH)
      expect(categories).to include(described_class::HARM_CATEGORY_DANGEROUS_CONTENT)
      expect(categories).to include(described_class::HARM_CATEGORY_HARASSMENT)
      expect(categories).to include(described_class::HARM_CATEGORY_SEXUALLY_EXPLICIT)
    end
  end

  describe "#initialize" do
    it "creates safety settings with array of settings" do
      settings = described_class.new([
        {category: described_class::HARM_CATEGORY_HATE_SPEECH, threshold: described_class::BLOCK_MEDIUM_AND_ABOVE}
      ])

      expect(settings).to be_a(Aigen::Google::SafetySettings)
    end

    it "creates safety settings with empty array" do
      settings = described_class.new([])

      expect(settings).to be_a(Aigen::Google::SafetySettings)
    end
  end

  describe "#to_h" do
    it "serializes to API format array" do
      settings = described_class.new([
        {category: described_class::HARM_CATEGORY_HATE_SPEECH, threshold: described_class::BLOCK_MEDIUM_AND_ABOVE},
        {category: described_class::HARM_CATEGORY_HARASSMENT, threshold: described_class::BLOCK_ONLY_HIGH}
      ])

      result = settings.to_h

      expect(result).to eq([
        {category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE"},
        {category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_ONLY_HIGH"}
      ])
    end

    it "returns empty array for empty settings" do
      settings = described_class.new([])

      expect(settings.to_h).to eq([])
    end

    it "preserves setting order" do
      input = [
        {category: described_class::HARM_CATEGORY_HARASSMENT, threshold: described_class::BLOCK_LOW_AND_ABOVE},
        {category: described_class::HARM_CATEGORY_HATE_SPEECH, threshold: described_class::BLOCK_NONE}
      ]
      settings = described_class.new(input)

      result = settings.to_h

      expect(result[0][:category]).to eq("HARM_CATEGORY_HARASSMENT")
      expect(result[1][:category]).to eq("HARM_CATEGORY_HATE_SPEECH")
    end
  end
end
