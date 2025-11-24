# frozen_string_literal: true

require "spec_helper"

RSpec.describe Aigen::Google::Client do
  let(:api_key) { "test-api-key-123" }

  describe "#initialize" do
    context "with instance configuration" do
      it "creates client with provided API key" do
        client = described_class.new(api_key: api_key)

        expect(client.config.api_key).to eq(api_key)
      end

      it "creates client with custom model" do
        client = described_class.new(api_key: api_key, model: "gemini-pro-vision")

        expect(client.config.default_model).to eq("gemini-pro-vision")
      end

      it "creates client with custom timeout" do
        client = described_class.new(api_key: api_key, timeout: 60)

        expect(client.config.timeout).to eq(60)
      end
    end

    context "with global configuration" do
      before do
        Aigen::Google.configure do |config|
          config.api_key = "global-api-key"
          config.default_model = "gemini-pro"
        end
      end

      after do
        Aigen::Google.configuration = nil
      end

      it "uses global configuration when no instance config provided" do
        client = described_class.new

        expect(client.config.api_key).to eq("global-api-key")
        expect(client.config.default_model).to eq("gemini-pro")
      end

      it "overrides global configuration with instance values" do
        client = described_class.new(api_key: "instance-key", model: "gemini-pro-vision")

        expect(client.config.api_key).to eq("instance-key")
        expect(client.config.default_model).to eq("gemini-pro-vision")
      end
    end

    context "without API key" do
      it "raises ConfigurationError when no API key provided" do
        expect {
          described_class.new
        }.to raise_error(Aigen::Google::ConfigurationError, /API key is required/)
      end
    end
  end

  describe "#generate_content" do
    let(:client) { described_class.new(api_key: api_key) }
    let(:prompt) { "Hello, world!" }

    it "sends request to Gemini API and returns response" do
      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
        .with(
          headers: {
            "Content-Type" => "application/json",
            "x-goog-api-key" => api_key
          },
          body: hash_including({
            contents: [{parts: [{text: prompt}]}]
          })
        )
        .to_return(
          status: 200,
          body: {
            candidates: [
              {
                content: {
                  parts: [{text: "Hi there! How can I help you?"}],
                  role: "model"
                },
                finishReason: "STOP"
              }
            ]
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      response = client.generate_content(prompt: prompt)

      expect(response).to be_a(Hash)
      expect(response["candidates"]).to be_an(Array)
      expect(response["candidates"].first["content"]["parts"].first["text"]).to include("Hi there")
    end

    it "uses custom model when specified" do
      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent")
        .to_return(
          status: 200,
          body: {candidates: [{content: {parts: [{text: "Response"}]}}]}.to_json
        )

      client.generate_content(prompt: prompt, model: "gemini-pro-vision")

      expect(WebMock).to have_requested(:post, /gemini-pro-vision:generateContent/)
    end

    it "passes additional options to the API" do
      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
        .with(
          body: hash_including({
            contents: [{parts: [{text: prompt}]}],
            generationConfig: {temperature: 0.7}
          })
        )
        .to_return(
          status: 200,
          body: {candidates: [{content: {parts: [{text: "Response"}]}}]}.to_json
        )

      client.generate_content(prompt: prompt, generationConfig: {temperature: 0.7})

      expect(WebMock).to have_requested(:post, /generateContent/).with { |req|
        body = JSON.parse(req.body)
        body.dig("generationConfig", "temperature")&.between?(0.69, 0.71)
      }
    end

    context "when API returns error" do
      it "raises AuthenticationError for invalid API key" do
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
          .to_return(status: 401, body: {error: {message: "Invalid API key"}}.to_json)

        expect {
          client.generate_content(prompt: prompt)
        }.to raise_error(Aigen::Google::AuthenticationError)
      end
    end
  end

  describe "#start_chat" do
    let(:client) { described_class.new(api_key: api_key) }

    it "returns a Chat instance" do
      chat = client.start_chat
      expect(chat).to be_a(Aigen::Google::Chat)
    end

    it "creates chat with empty history by default" do
      chat = client.start_chat
      expect(chat.history).to eq([])
    end

    it "creates chat with provided initial history" do
      initial_history = [
        {role: "user", parts: [{text: "Hello"}]},
        {role: "model", parts: [{text: "Hi"}]}
      ]
      chat = client.start_chat(history: initial_history)
      expect(chat.history).to eq(initial_history)
    end

    it "creates chat with custom model" do
      chat = client.start_chat(model: "gemini-pro-vision")

      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent")
        .to_return(
          status: 200,
          body: {candidates: [{content: {parts: [{text: "Response"}], role: "model"}}]}.to_json
        )

      chat.send_message("Test")
      expect(WebMock).to have_requested(:post, /gemini-pro-vision:generateContent/)
    end

    it "creates chat with default model from client config" do
      chat = client.start_chat

      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
        .to_return(
          status: 200,
          body: {candidates: [{content: {parts: [{text: "Response"}], role: "model"}}]}.to_json
        )

      chat.send_message("Test")
      expect(WebMock).to have_requested(:post, /gemini-pro:generateContent/)
    end
  end

  describe "#generate_content_stream" do
    let(:client) { described_class.new(api_key: api_key) }
    let(:prompt) { "Tell me a story" }

    context "with block given" do
      it "yields progressive chunks to the block" do
        chunks = [
          {candidates: [{content: {parts: [{text: "Once"}], role: "model"}}]},
          {candidates: [{content: {parts: [{text: " upon"}], role: "model"}}]},
          {candidates: [{content: {parts: [{text: " a time"}], role: "model"}}]}
        ]
        chunk_data = chunks.map { |c| "#{c.to_json}\n" }.join

        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent")
          .to_return(status: 200, body: chunk_data)

        received_texts = []
        client.generate_content_stream(prompt: prompt) do |chunk|
          received_texts << chunk["candidates"][0]["content"]["parts"][0]["text"]
        end

        expect(received_texts).to eq(["Once", " upon", " a time"])
      end

      it "returns nil when block is given" do
        chunk_data = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hi\"}]}}]}\n"

        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent")
          .to_return(status: 200, body: chunk_data)

        result = client.generate_content_stream(prompt: prompt) { |chunk| }
        expect(result).to be_nil
      end

      it "uses custom model when specified" do
        chunk_data = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hi\"}]}}]}\n"

        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:streamGenerateContent")
          .to_return(status: 200, body: chunk_data)

        client.generate_content_stream(prompt: prompt, model: "gemini-pro-vision") { |chunk| }
        expect(WebMock).to have_requested(:post, /gemini-pro-vision:streamGenerateContent/)
      end

      it "passes additional options to the API" do
        chunk_data = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hi\"}]}}]}\n"

        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent")
          .with(body: hash_including({
            generationConfig: {temperature: 0.9}
          }))
          .to_return(status: 200, body: chunk_data)

        client.generate_content_stream(prompt: prompt, generationConfig: {temperature: 0.9}) { |chunk| }
      end
    end

    context "without block (Enumerator)" do
      it "returns an Enumerator" do
        chunk_data = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hi\"}]}}]}\n"

        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent")
          .to_return(status: 200, body: chunk_data)

        result = client.generate_content_stream(prompt: prompt)
        expect(result).to be_a(Enumerator)
      end

      it "enumerates chunks when iterated" do
        chunks = [
          {candidates: [{content: {parts: [{text: "One"}], role: "model"}}]},
          {candidates: [{content: {parts: [{text: "Two"}], role: "model"}}]}
        ]
        chunk_data = chunks.map { |c| "#{c.to_json}\n" }.join

        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent")
          .to_return(status: 200, body: chunk_data)

        enum = client.generate_content_stream(prompt: prompt)
        collected = enum.to_a

        expect(collected.length).to eq(2)
        expect(collected[0]["candidates"][0]["content"]["parts"][0]["text"]).to eq("One")
      end

      it "supports lazy operations" do
        chunks = [
          {candidates: [{content: {parts: [{text: "One"}], role: "model"}}]},
          {candidates: [{content: {parts: [{text: "Two"}], role: "model"}}]},
          {candidates: [{content: {parts: [{text: "Three"}], role: "model"}}]}
        ]
        chunk_data = chunks.map { |c| "#{c.to_json}\n" }.join

        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent")
          .to_return(status: 200, body: chunk_data)

        enum = client.generate_content_stream(prompt: prompt)
        first_two = enum.lazy.take(2).to_a

        expect(first_two.length).to eq(2)
      end
    end

    context "when API returns error" do
      it "raises AuthenticationError for invalid API key" do
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent")
          .to_return(status: 401, body: {error: {message: "Invalid API key"}}.to_json)

        expect {
          client.generate_content_stream(prompt: prompt) { |chunk| }
        }.to raise_error(Aigen::Google::AuthenticationError)
      end
    end
  end

  describe "multimodal content support" do
    let(:client) { described_class.new(api_key: api_key) }
    let(:response_body) do
      {
        candidates: [
          {
            content: {
              parts: [{text: "This is a multimodal response"}],
              role: "model"
            }
          }
        ]
      }
    end

    context "with contents parameter" do
      it "sends multimodal request with text and image" do
        text_content = Aigen::Google::Content.text("What is in this image?")
        image_content = Aigen::Google::Content.image(data: "base64data", mime_type: "image/jpeg")

        stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
          .with { |req|
            body = JSON.parse(req.body)
            body["contents"].is_a?(Array) &&
              body["contents"].length == 2 &&
              body["contents"][0]["parts"][0]["text"] == "What is in this image?" &&
              body["contents"][1]["parts"][0]["inline_data"]["mime_type"] == "image/jpeg"
          }
          .to_return(status: 200, body: response_body.to_json)

        client.generate_content(contents: [text_content.to_h, image_content.to_h])

        expect(stub).to have_been_requested
      end
    end

    context "with temperature parameter" do
      it "includes generationConfig in request" do
        stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
          .with { |req|
            body = JSON.parse(req.body)
            body["generationConfig"] &&
              (body["generationConfig"]["temperature"] - 0.5).abs < 0.001
          }
          .to_return(status: 200, body: response_body.to_json)

        client.generate_content(prompt: "Hello", temperature: 0.5)

        expect(stub).to have_been_requested
      end
    end

    context "with all generation config parameters" do
      it "includes all parameters with camelCase keys" do
        stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
          .with { |req|
            body = JSON.parse(req.body)
            config = body["generationConfig"]
            (config["temperature"] - 0.7).abs < 0.001 &&
              (config["topP"] - 0.9).abs < 0.001 &&
              config["topK"] == 40 &&
              config["maxOutputTokens"] == 1024
          }
          .to_return(status: 200, body: response_body.to_json)

        client.generate_content(
          prompt: "Hello",
          temperature: 0.7,
          top_p: 0.9,
          top_k: 40,
          max_output_tokens: 1024
        )

        expect(stub).to have_been_requested
      end
    end

    context "with safety_settings parameter" do
      it "includes safetySettings in request" do
        settings = [
          {category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE"}
        ]

        stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
          .with { |req|
            body = JSON.parse(req.body)
            body["safetySettings"].is_a?(Array) &&
              body["safetySettings"].length == 1 &&
              body["safetySettings"][0]["category"] == "HARM_CATEGORY_HATE_SPEECH" &&
              body["safetySettings"][0]["threshold"] == "BLOCK_MEDIUM_AND_ABOVE"
          }
          .to_return(status: 200, body: response_body.to_json)

        client.generate_content(prompt: "Hello", safety_settings: settings)

        expect(stub).to have_been_requested
      end
    end

    context "backward compatibility" do
      it "still accepts simple prompt parameter" do
        stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
          .with { |req|
            body = JSON.parse(req.body)
            body["contents"][0]["parts"][0]["text"] == "Hello"
          }
          .to_return(status: 200, body: response_body.to_json)

        client.generate_content(prompt: "Hello")

        expect(stub).to have_been_requested
      end
    end

    context "validation" do
      it "raises InvalidRequestError for invalid temperature before API call" do
        expect {
          client.generate_content(prompt: "Hello", temperature: 1.5)
        }.to raise_error(Aigen::Google::InvalidRequestError, /temperature must be between 0.0 and 1.0/)
      end

      it "raises InvalidRequestError for invalid top_p" do
        expect {
          client.generate_content(prompt: "Hello", top_p: 1.5)
        }.to raise_error(Aigen::Google::InvalidRequestError, /top_p must be between 0.0 and 1.0/)
      end

      it "raises InvalidRequestError for invalid top_k" do
        expect {
          client.generate_content(prompt: "Hello", top_k: 0)
        }.to raise_error(Aigen::Google::InvalidRequestError, /top_k must be greater than 0/)
      end

      it "raises InvalidRequestError for invalid max_output_tokens" do
        expect {
          client.generate_content(prompt: "Hello", max_output_tokens: 0)
        }.to raise_error(Aigen::Google::InvalidRequestError, /max_output_tokens must be greater than 0/)
      end
    end

    context "image generation parameters" do
      it "includes responseModalities in request" do
        stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
          .with { |req|
            body = JSON.parse(req.body)
            body["generationConfig"] &&
              body["generationConfig"]["responseModalities"] == ["TEXT", "IMAGE"]
          }
          .to_return(status: 200, body: response_body.to_json)

        client.generate_content(
          prompt: "Generate an image",
          response_modalities: ["TEXT", "IMAGE"]
        )

        expect(stub).to have_been_requested
      end

      it "includes aspectRatio in imageConfig" do
        stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
          .with { |req|
            body = JSON.parse(req.body)
            body["generationConfig"] &&
              body["generationConfig"]["imageConfig"] &&
              body["generationConfig"]["imageConfig"]["aspectRatio"] == "16:9"
          }
          .to_return(status: 200, body: response_body.to_json)

        client.generate_content(
          prompt: "Generate an image",
          aspect_ratio: "16:9"
        )

        expect(stub).to have_been_requested
      end

      it "includes imageSize in imageConfig" do
        stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
          .with { |req|
            body = JSON.parse(req.body)
            body["generationConfig"] &&
              body["generationConfig"]["imageConfig"] &&
              body["generationConfig"]["imageConfig"]["imageSize"] == "2K"
          }
          .to_return(status: 200, body: response_body.to_json)

        client.generate_content(
          prompt: "Generate an image",
          image_size: "2K"
        )

        expect(stub).to have_been_requested
      end

      it "includes all image generation parameters with proper nesting" do
        stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
          .with { |req|
            body = JSON.parse(req.body)
            config = body["generationConfig"]
            image_config = config["imageConfig"]
            config["responseModalities"] == ["TEXT", "IMAGE"] &&
              image_config &&
              image_config["aspectRatio"] == "16:9" &&
              image_config["imageSize"] == "2K"
          }
          .to_return(status: 200, body: response_body.to_json)

        client.generate_content(
          prompt: "Generate a landscape image",
          response_modalities: ["TEXT", "IMAGE"],
          aspect_ratio: "16:9",
          image_size: "2K"
        )

        expect(stub).to have_been_requested
      end

      it "validates response_modalities" do
        expect {
          client.generate_content(prompt: "Hello", response_modalities: ["INVALID"])
        }.to raise_error(Aigen::Google::InvalidRequestError, /response_modalities must only contain TEXT or IMAGE/)
      end

      it "validates aspect_ratio" do
        expect {
          client.generate_content(prompt: "Hello", aspect_ratio: "invalid")
        }.to raise_error(Aigen::Google::InvalidRequestError, /aspect_ratio must be one of/)
      end

      it "validates image_size" do
        expect {
          client.generate_content(prompt: "Hello", image_size: "8K")
        }.to raise_error(Aigen::Google::InvalidRequestError, /image_size must be one of/)
      end
    end
  end
end
