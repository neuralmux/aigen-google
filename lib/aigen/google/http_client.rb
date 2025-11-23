# frozen_string_literal: true

require "faraday"
require "json"

module Aigen
  module Google
    class HttpClient
      BASE_URL = "https://generativelanguage.googleapis.com/v1beta"

      def initialize(api_key:, timeout: 30, retry_count: 3)
        @api_key = api_key
        @timeout = timeout
        @retry_count = retry_count
      end

      def post(path, payload, attempt: 1)
        response = connection.post(path) do |req|
          req.headers["Content-Type"] = "application/json"
          req.headers["x-goog-api-key"] = @api_key
          req.body = payload.to_json
        end

        handle_response(response, path, payload, attempt)
      rescue Faraday::Error => e
        # Handle timeout-like errors (including WebMock's .to_timeout)
        is_timeout = e.is_a?(Faraday::TimeoutError) ||
          e.is_a?(::Timeout::Error) ||
          e.message.include?("execution expired") ||
          e.message.include?("timed out")

        if is_timeout
          if attempt >= @retry_count
            raise TimeoutError, "Request timed out after #{@retry_count} retries"
          end
          backoff_seconds = 2**(attempt - 1) # 1s, 2s, 4s
          sleep backoff_seconds
          post(path, payload, attempt: attempt + 1)
        else
          # Network connection errors
          raise ServerError.new("Network error: #{e.message}", status_code: nil)
        end
      end

      private

      def connection
        @connection ||= Faraday.new(url: BASE_URL) do |conn|
          conn.options.timeout = @timeout
          conn.adapter Faraday.default_adapter do |http|
            http.open_timeout = 5
            http.read_timeout = @timeout
          end
        end
      end

      def handle_response(response, path, payload, attempt)
        case response.status
        when 200..299
          begin
            JSON.parse(response.body)
          rescue JSON::ParserError => e
            raise ServerError.new("Invalid JSON response from API: #{e.message}", status_code: response.status)
          end
        when 400
          raise InvalidRequestError.new(extract_error_message(response), status_code: 400)
        when 401, 403
          raise AuthenticationError.new("Invalid API key. Get one at https://makersuite.google.com/app/apikey", status_code: response.status)
        when 404
          raise InvalidRequestError.new("Resource not found. Check model name and endpoint.", status_code: 404)
        when 429
          retry_response(path, payload, attempt, RateLimitError.new(extract_error_message(response), status_code: 429))
        when 500..599
          retry_response(path, payload, attempt, ServerError.new(extract_error_message(response), status_code: response.status))
        else
          raise ApiError.new("Unexpected status code: #{response.status}", status_code: response.status)
        end
      end

      def retry_response(path, payload, attempt, error)
        if attempt >= @retry_count
          raise error
        end

        backoff_seconds = 2**(attempt - 1) # 1s, 2s, 4s
        sleep backoff_seconds
        post(path, payload, attempt: attempt + 1)
      end

      def extract_error_message(response)
        body = JSON.parse(response.body)
        body.dig("error", "message") || response.body
      rescue JSON::ParserError
        response.body
      end
    end
  end
end
