# frozen_string_literal: true

RSpec.describe Aigen::Google do
  describe "Error hierarchy" do
    it "defines base Error class" do
      expect(Aigen::Google::Error).to be < StandardError
    end

    it "defines ConfigurationError" do
      expect(Aigen::Google::ConfigurationError).to be < Aigen::Google::Error
    end

    it "defines ApiError with status_code attribute" do
      error = Aigen::Google::ApiError.new("test message", status_code: 400)

      expect(error).to be_a(Aigen::Google::Error)
      expect(error.message).to eq("test message")
      expect(error.status_code).to eq(400)
    end

    it "defines AuthenticationError with default message" do
      error = Aigen::Google::AuthenticationError.new

      expect(error).to be_a(Aigen::Google::ApiError)
      expect(error.message).to include("Invalid API key")
      expect(error.message).to include("makersuite.google.com")
      expect(error.status_code).to eq(401)
    end

    it "defines RateLimitError with default message" do
      error = Aigen::Google::RateLimitError.new

      expect(error).to be_a(Aigen::Google::ApiError)
      expect(error.message).to include("Rate limit exceeded")
      expect(error.status_code).to eq(429)
    end

    it "defines InvalidRequestError with default message" do
      error = Aigen::Google::InvalidRequestError.new

      expect(error).to be_a(Aigen::Google::ApiError)
      expect(error.message).to include("Invalid request")
      expect(error.status_code).to eq(400)
    end

    it "defines ServerError with default message" do
      error = Aigen::Google::ServerError.new

      expect(error).to be_a(Aigen::Google::ApiError)
      expect(error.message).to include("server error")
      expect(error.status_code).to eq(500)
    end

    it "defines TimeoutError" do
      error = Aigen::Google::TimeoutError.new

      expect(error).to be_a(Aigen::Google::Error)
      expect(error.message).to include("timed out")
    end
  end

  describe "custom error messages" do
    it "allows custom message for AuthenticationError" do
      error = Aigen::Google::AuthenticationError.new("Custom auth error", status_code: 403)

      expect(error.message).to eq("Custom auth error")
      expect(error.status_code).to eq(403)
    end

    it "allows custom message for other errors" do
      error = Aigen::Google::ServerError.new("Custom server error", status_code: 503)

      expect(error.message).to eq("Custom server error")
      expect(error.status_code).to eq(503)
    end
  end
end
