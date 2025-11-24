# frozen_string_literal: true

RSpec.describe Aigen::Google::GenerationConfig do
  describe "#initialize" do
    it "creates config with valid temperature" do
      config = described_class.new(temperature: 0.5)
      expect(config).to be_a(Aigen::Google::GenerationConfig)
    end

    it "creates config with valid top_p" do
      config = described_class.new(top_p: 0.8)
      expect(config).to be_a(Aigen::Google::GenerationConfig)
    end

    it "creates config with valid top_k" do
      config = described_class.new(top_k: 40)
      expect(config).to be_a(Aigen::Google::GenerationConfig)
    end

    it "creates config with valid max_output_tokens" do
      config = described_class.new(max_output_tokens: 1024)
      expect(config).to be_a(Aigen::Google::GenerationConfig)
    end

    it "creates config with all parameters" do
      config = described_class.new(
        temperature: 0.7,
        top_p: 0.9,
        top_k: 40,
        max_output_tokens: 2048
      )
      expect(config).to be_a(Aigen::Google::GenerationConfig)
    end

    it "creates config with response_modalities" do
      config = described_class.new(response_modalities: ["TEXT", "IMAGE"])
      expect(config).to be_a(Aigen::Google::GenerationConfig)
    end

    it "creates config with aspect_ratio" do
      config = described_class.new(aspect_ratio: "16:9")
      expect(config).to be_a(Aigen::Google::GenerationConfig)
    end

    it "creates config with image_size" do
      config = described_class.new(image_size: "2K")
      expect(config).to be_a(Aigen::Google::GenerationConfig)
    end

    it "creates config with all image generation parameters" do
      config = described_class.new(
        response_modalities: ["TEXT", "IMAGE"],
        aspect_ratio: "16:9",
        image_size: "2K"
      )
      expect(config).to be_a(Aigen::Google::GenerationConfig)
    end

    it "creates config with no parameters" do
      config = described_class.new
      expect(config).to be_a(Aigen::Google::GenerationConfig)
    end
  end

  describe "validation" do
    context "temperature" do
      it "raises error when temperature > 1.0" do
        expect {
          described_class.new(temperature: 1.5)
        }.to raise_error(Aigen::Google::InvalidRequestError, /temperature must be between 0.0 and 1.0/)
      end

      it "raises error when temperature < 0.0" do
        expect {
          described_class.new(temperature: -0.1)
        }.to raise_error(Aigen::Google::InvalidRequestError, /temperature must be between 0.0 and 1.0/)
      end

      it "accepts temperature = 0.0" do
        expect { described_class.new(temperature: 0.0) }.not_to raise_error
      end

      it "accepts temperature = 1.0" do
        expect { described_class.new(temperature: 1.0) }.not_to raise_error
      end
    end

    context "top_p" do
      it "raises error when top_p > 1.0" do
        expect {
          described_class.new(top_p: 1.5)
        }.to raise_error(Aigen::Google::InvalidRequestError, /top_p must be between 0.0 and 1.0/)
      end

      it "raises error when top_p < 0.0" do
        expect {
          described_class.new(top_p: -0.1)
        }.to raise_error(Aigen::Google::InvalidRequestError, /top_p must be between 0.0 and 1.0/)
      end
    end

    context "top_k" do
      it "raises error when top_k <= 0" do
        expect {
          described_class.new(top_k: 0)
        }.to raise_error(Aigen::Google::InvalidRequestError, /top_k must be greater than 0/)
      end

      it "raises error when top_k is negative" do
        expect {
          described_class.new(top_k: -5)
        }.to raise_error(Aigen::Google::InvalidRequestError, /top_k must be greater than 0/)
      end

      it "accepts top_k = 1" do
        expect { described_class.new(top_k: 1) }.not_to raise_error
      end
    end

    context "max_output_tokens" do
      it "raises error when max_output_tokens <= 0" do
        expect {
          described_class.new(max_output_tokens: 0)
        }.to raise_error(Aigen::Google::InvalidRequestError, /max_output_tokens must be greater than 0/)
      end

      it "raises error when max_output_tokens is negative" do
        expect {
          described_class.new(max_output_tokens: -100)
        }.to raise_error(Aigen::Google::InvalidRequestError, /max_output_tokens must be greater than 0/)
      end

      it "accepts max_output_tokens = 1" do
        expect { described_class.new(max_output_tokens: 1) }.not_to raise_error
      end
    end

    context "response_modalities" do
      it "accepts valid modalities array" do
        expect { described_class.new(response_modalities: ["TEXT"]) }.not_to raise_error
        expect { described_class.new(response_modalities: ["IMAGE"]) }.not_to raise_error
        expect { described_class.new(response_modalities: ["TEXT", "IMAGE"]) }.not_to raise_error
      end

      it "raises error for invalid modality" do
        expect {
          described_class.new(response_modalities: ["INVALID"])
        }.to raise_error(Aigen::Google::InvalidRequestError, /response_modalities must only contain TEXT or IMAGE/)
      end

      it "raises error when not an array" do
        expect {
          described_class.new(response_modalities: "TEXT")
        }.to raise_error(Aigen::Google::InvalidRequestError, /response_modalities must be an array/)
      end

      it "raises error for empty array" do
        expect {
          described_class.new(response_modalities: [])
        }.to raise_error(Aigen::Google::InvalidRequestError, /response_modalities must not be empty/)
      end
    end

    context "aspect_ratio" do
      it "accepts valid aspect ratios" do
        valid_ratios = ["1:1", "16:9", "9:16", "4:3", "3:4", "5:4", "4:5"]
        valid_ratios.each do |ratio|
          expect { described_class.new(aspect_ratio: ratio) }.not_to raise_error
        end
      end

      it "raises error for invalid aspect ratio" do
        expect {
          described_class.new(aspect_ratio: "invalid")
        }.to raise_error(Aigen::Google::InvalidRequestError, /aspect_ratio must be one of/)
      end
    end

    context "image_size" do
      it "accepts valid image sizes" do
        expect { described_class.new(image_size: "1K") }.not_to raise_error
        expect { described_class.new(image_size: "2K") }.not_to raise_error
        expect { described_class.new(image_size: "4K") }.not_to raise_error
      end

      it "raises error for invalid image size" do
        expect {
          described_class.new(image_size: "8K")
        }.to raise_error(Aigen::Google::InvalidRequestError, /image_size must be one of/)
      end

      it "raises error for lowercase image size" do
        expect {
          described_class.new(image_size: "2k")
        }.to raise_error(Aigen::Google::InvalidRequestError, /image_size must be one of/)
      end
    end
  end

  describe "#to_h" do
    it "serializes with camelCase keys" do
      config = described_class.new(
        temperature: 0.5,
        top_p: 0.9,
        top_k: 40,
        max_output_tokens: 1024
      )

      result = config.to_h

      expect(result).to eq({
        temperature: 0.5,
        topP: 0.9,
        topK: 40,
        maxOutputTokens: 1024
      })
    end

    it "omits nil values" do
      config = described_class.new(temperature: 0.7)

      result = config.to_h

      expect(result).to eq({temperature: 0.7})
      expect(result).not_to have_key(:topP)
      expect(result).not_to have_key(:topK)
      expect(result).not_to have_key(:maxOutputTokens)
    end

    it "returns empty hash when no parameters set" do
      config = described_class.new

      expect(config.to_h).to eq({})
    end

    it "handles temperature = 0" do
      config = described_class.new(temperature: 0.0)

      expect(config.to_h).to eq({temperature: 0.0})
    end

    it "serializes response_modalities" do
      config = described_class.new(response_modalities: ["TEXT", "IMAGE"])

      result = config.to_h

      expect(result).to eq({responseModalities: ["TEXT", "IMAGE"]})
    end

    it "serializes aspect_ratio under imageConfig" do
      config = described_class.new(aspect_ratio: "16:9")

      result = config.to_h

      expect(result).to eq({imageConfig: {aspectRatio: "16:9"}})
    end

    it "serializes image_size under imageConfig" do
      config = described_class.new(image_size: "2K")

      result = config.to_h

      expect(result).to eq({imageConfig: {imageSize: "2K"}})
    end

    it "serializes all image generation parameters" do
      config = described_class.new(
        response_modalities: ["TEXT", "IMAGE"],
        aspect_ratio: "16:9",
        image_size: "2K",
        temperature: 0.7
      )

      result = config.to_h

      expect(result).to eq({
        responseModalities: ["TEXT", "IMAGE"],
        imageConfig: {
          aspectRatio: "16:9",
          imageSize: "2K"
        },
        temperature: 0.7
      })
    end

    it "serializes aspect_ratio and image_size together under imageConfig" do
      config = described_class.new(
        aspect_ratio: "16:9",
        image_size: "2K"
      )

      result = config.to_h

      expect(result).to eq({
        imageConfig: {
          aspectRatio: "16:9",
          imageSize: "2K"
        }
      })
    end
  end
end
