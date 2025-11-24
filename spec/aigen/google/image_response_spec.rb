# frozen_string_literal: true

RSpec.describe Aigen::Google::ImageResponse do
  let(:successful_response) do
    {
      "candidates" => [
        {
          "content" => {
            "parts" => [
              {"text" => "A beautiful sunset over mountains"},
              {
                "inlineData" => {
                  "mimeType" => "image/png",
                  "data" => "aGVsbG8gd29ybGQ="  # "hello world" in base64
                }
              }
            ]
          },
          "finishReason" => "STOP"
        }
      ]
    }
  end

  let(:failed_response) do
    {
      "candidates" => [
        {
          "finishReason" => "IMAGE_OTHER",
          "finishMessage" => "Unable to generate image"
        }
      ]
    }
  end

  let(:text_only_response) do
    {
      "candidates" => [
        {
          "content" => {
            "parts" => [
              {"text" => "Just text, no image"}
            ]
          },
          "finishReason" => "STOP"
        }
      ]
    }
  end

  describe "#initialize" do
    it "creates an ImageResponse from successful API response" do
      response = described_class.new(successful_response)
      expect(response).to be_a(Aigen::Google::ImageResponse)
    end
  end

  describe "#success?" do
    it "returns true for successful generation" do
      response = described_class.new(successful_response)
      expect(response.success?).to be true
    end

    it "returns false for failed generation" do
      response = described_class.new(failed_response)
      expect(response.success?).to be false
    end
  end

  describe "#has_image?" do
    it "returns true when image is present" do
      response = described_class.new(successful_response)
      expect(response.has_image?).to be true
    end

    it "returns false when no image present" do
      response = described_class.new(text_only_response)
      expect(response.has_image?).to be false
    end

    it "returns false for failed response" do
      response = described_class.new(failed_response)
      expect(response.has_image?).to be false
    end
  end

  describe "#text" do
    it "returns the text description" do
      response = described_class.new(successful_response)
      expect(response.text).to eq("A beautiful sunset over mountains")
    end

    it "returns nil when no text present" do
      response = described_class.new({
        "candidates" => [
          {
            "content" => {
              "parts" => [
                {
                  "inlineData" => {
                    "mimeType" => "image/png",
                    "data" => "aGVsbG8gd29ybGQ="
                  }
                }
              ]
            },
            "finishReason" => "STOP"
          }
        ]
      })
      expect(response.text).to be_nil
    end
  end

  describe "#image_data" do
    it "returns decoded image data" do
      response = described_class.new(successful_response)
      expect(response.image_data).to eq("hello world")  # Decoded base64
    end

    it "returns nil when no image present" do
      response = described_class.new(text_only_response)
      expect(response.image_data).to be_nil
    end
  end

  describe "#mime_type" do
    it "returns the image MIME type" do
      response = described_class.new(successful_response)
      expect(response.mime_type).to eq("image/png")
    end

    it "returns nil when no image present" do
      response = described_class.new(text_only_response)
      expect(response.mime_type).to be_nil
    end
  end

  describe "#save" do
    it "saves image to specified path" do
      response = described_class.new(successful_response)

      allow(File).to receive(:write)

      response.save("test.png")

      expect(File).to have_received(:write).with("test.png", "hello world")
    end

    it "raises error when no image present" do
      response = described_class.new(text_only_response)

      expect {
        response.save("test.png")
      }.to raise_error(Aigen::Google::Error, /No image data/)
    end
  end

  describe "#failure_reason" do
    it "returns nil for successful response" do
      response = described_class.new(successful_response)
      expect(response.failure_reason).to be_nil
    end

    it "returns finish reason for failed response" do
      response = described_class.new(failed_response)
      expect(response.failure_reason).to eq("IMAGE_OTHER")
    end
  end

  describe "#failure_message" do
    it "returns nil for successful response" do
      response = described_class.new(successful_response)
      expect(response.failure_message).to be_nil
    end

    it "returns finish message for failed response" do
      response = described_class.new(failed_response)
      expect(response.failure_message).to eq("Unable to generate image")
    end
  end

  describe "#raw_response" do
    it "returns the original API response" do
      response = described_class.new(successful_response)
      expect(response.raw_response).to eq(successful_response)
    end
  end
end
