# frozen_string_literal: true

module Aigen
  module Google
    # Base error class for all gem exceptions
    class Error < StandardError; end

    # Configuration-related errors
    class ConfigurationError < Error; end

    # Base class for API-related errors
    class ApiError < Error
      attr_reader :status_code

      def initialize(message, status_code: nil)
        super(message)
        @status_code = status_code
      end
    end

    # Authentication errors (401, 403)
    class AuthenticationError < ApiError
      def initialize(message = "Invalid API key. Get one at https://makersuite.google.com/app/apikey", status_code: 401)
        super
      end
    end

    # Rate limit exceeded (429)
    class RateLimitError < ApiError
      def initialize(message = "Rate limit exceeded. Please retry after some time.", status_code: 429)
        super
      end
    end

    # Invalid request errors (400, 404)
    class InvalidRequestError < ApiError
      def initialize(message = "Invalid request. Check your parameters.", status_code: 400)
        super
      end
    end

    # Server errors (500-599)
    class ServerError < ApiError
      def initialize(message = "Google API server error. Please retry.", status_code: 500)
        super
      end
    end

    # Timeout errors
    class TimeoutError < Error
      def initialize(message = "Request timed out after retries.")
        super
      end
    end
  end
end
