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
end
