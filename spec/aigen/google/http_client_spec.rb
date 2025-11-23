# frozen_string_literal: true

require "spec_helper"

RSpec.describe Aigen::Google::HttpClient do
  let(:api_key) { "test-api-key-123" }
  let(:http_client) { described_class.new(api_key: api_key, timeout: 30, retry_count: 3) }

  describe "#post" do
    let(:path) { "models/gemini-pro:generateContent" }
    let(:payload) { {contents: [{parts: [{text: "Hello"}]}]} }

    context "when request is successful" do
      it "returns parsed JSON response", :vcr do
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/#{path}")
          .with(
            headers: {
              "Content-Type" => "application/json",
              "x-goog-api-key" => api_key
            },
            body: payload.to_json
          )
          .to_return(
            status: 200,
            body: {candidates: [{content: {parts: [{text: "Hi there!"}]}}]}.to_json,
            headers: {"Content-Type" => "application/json"}
          )

        response = http_client.post(path, payload)

        expect(response).to be_a(Hash)
        expect(response).to have_key("candidates")
      end
    end

    context "when API key is invalid" do
      it "raises AuthenticationError for 401 status" do
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/#{path}")
          .to_return(status: 401, body: {error: {message: "Invalid API key"}}.to_json)

        expect {
          http_client.post(path, payload)
        }.to raise_error(Aigen::Google::AuthenticationError, /Invalid API key/)
      end

      it "raises AuthenticationError for 403 status" do
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/#{path}")
          .to_return(status: 403, body: {error: {message: "Forbidden"}}.to_json)

        expect {
          http_client.post(path, payload)
        }.to raise_error(Aigen::Google::AuthenticationError)
      end
    end

    context "when request is malformed" do
      it "raises InvalidRequestError for 400 status" do
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/#{path}")
          .to_return(status: 400, body: {error: {message: "Bad request"}}.to_json)

        expect {
          http_client.post(path, payload)
        }.to raise_error(Aigen::Google::InvalidRequestError, /Bad request/)
      end

      it "raises InvalidRequestError for 404 status" do
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/#{path}")
          .to_return(status: 404, body: {error: {message: "Not found"}}.to_json)

        expect {
          http_client.post(path, payload)
        }.to raise_error(Aigen::Google::InvalidRequestError, /Resource not found/)
      end
    end

    context "when rate limited" do
      it "retries and eventually raises RateLimitError" do
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/#{path}")
          .to_return(status: 429, body: {error: {message: "Rate limit exceeded"}}.to_json)

        expect {
          http_client.post(path, payload)
        }.to raise_error(Aigen::Google::RateLimitError)
      end
    end

    context "when server error occurs" do
      it "retries and eventually raises ServerError for 500" do
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/#{path}")
          .to_return(status: 500, body: {error: {message: "Internal server error"}}.to_json)

        expect {
          http_client.post(path, payload)
        }.to raise_error(Aigen::Google::ServerError)
      end

      it "retries and eventually raises ServerError for 503" do
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/#{path}")
          .to_return(status: 503, body: {error: {message: "Service unavailable"}}.to_json)

        expect {
          http_client.post(path, payload)
        }.to raise_error(Aigen::Google::ServerError)
      end
    end

    context "when request times out" do
      it "raises TimeoutError after retries" do
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/#{path}")
          .to_timeout

        expect {
          http_client.post(path, payload)
        }.to raise_error(Aigen::Google::TimeoutError, /timed out after 3 retries/)
      end
    end

    context "when network error occurs" do
      it "raises ServerError with network error message" do
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/#{path}")
          .to_raise(Faraday::ConnectionFailed.new("Connection failed"))

        expect {
          http_client.post(path, payload)
        }.to raise_error(Aigen::Google::ServerError, /Network error/)
      end
    end
  end
end
