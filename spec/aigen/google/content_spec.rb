# frozen_string_literal: true

RSpec.describe Aigen::Google::Content do
  describe ".text" do
    it "creates text content with correct structure" do
      content = described_class.text("Hello, world!")

      expect(content).to be_a(Aigen::Google::Content)
      expect(content.to_h).to eq({
        parts: [{text: "Hello, world!"}]
      })
    end

    it "handles empty strings" do
      content = described_class.text("")

      expect(content.to_h).to eq({
        parts: [{text: ""}]
      })
    end
  end

  describe ".image" do
    let(:image_data) { "base64encodeddata" }
    let(:mime_type) { "image/jpeg" }

    it "creates image content with inline_data structure" do
      content = described_class.image(data: image_data, mime_type: mime_type)

      expect(content).to be_a(Aigen::Google::Content)
      expect(content.to_h).to eq({
        parts: [{
          inline_data: {
            mime_type: "image/jpeg",
            data: "base64encodeddata"
          }
        }]
      })
    end

    it "supports different mime types" do
      content = described_class.image(data: "data", mime_type: "image/png")

      expect(content.to_h[:parts][0][:inline_data][:mime_type]).to eq("image/png")
    end
  end

  describe ".new with multiple parts" do
    it "combines text and image parts" do
      text_part = {text: "Look at this image:"}
      image_part = {
        inline_data: {
          mime_type: "image/jpeg",
          data: "base64data"
        }
      }

      content = described_class.new([text_part, image_part])

      expect(content.to_h).to eq({
        parts: [text_part, image_part]
      })
    end

    it "supports single part array" do
      text_part = {text: "Hello"}
      content = described_class.new([text_part])

      expect(content.to_h).to eq({
        parts: [text_part]
      })
    end
  end

  describe "#to_h" do
    it "serializes to API format" do
      content = described_class.text("Test")

      expect(content.to_h).to be_a(Hash)
      expect(content.to_h).to have_key(:parts)
      expect(content.to_h[:parts]).to be_an(Array)
    end
  end
end
