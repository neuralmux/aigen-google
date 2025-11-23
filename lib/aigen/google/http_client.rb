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

      # Makes a streaming POST request to the Gemini API.
      # Processes chunked responses and yields each parsed chunk to the provided block.
      #
      # @param path [String] the API endpoint path
      # @param payload [Hash] the request payload (will be JSON encoded)
      # @yieldparam chunk [Hash] parsed JSON chunk from the streaming response
      #
      # @return [nil] always returns nil when block is given
      #
      # @raise [ArgumentError] if no block is provided
      # @raise [Aigen::Google::AuthenticationError] if API key is invalid (401/403)
      # @raise [Aigen::Google::InvalidRequestError] if request is malformed (400/404)
      # @raise [Aigen::Google::RateLimitError] if rate limit is exceeded (429)
      # @raise [Aigen::Google::ServerError] if server error occurs (500+) or network error
      #
      # @example Stream generated content chunks
      #   http_client.post_stream("models/gemini-pro:streamGenerateContent", payload) do |chunk|
      #     text = chunk["candidates"][0]["content"]["parts"][0]["text"]
      #     print text
      #   end
      def post_stream(path, payload, &block)
        raise ArgumentError, "block required for streaming" unless block_given?

        buffer = ""

        response = connection.post(path) do |req|
          req.headers["Content-Type"] = "application/json"
          req.headers["x-goog-api-key"] = @api_key
          req.body = payload.to_json

          req.options.on_data = proc do |chunk, _total_bytes|
            buffer += chunk

            # Process complete lines (newline-delimited JSON)
            while (newline_index = buffer.index("\n"))
              line = buffer.slice!(0, newline_index + 1).strip
              next if line.empty?

              begin
                parsed_chunk = JSON.parse(line)
                block.call(parsed_chunk)
              rescue JSON::ParserError => e
                raise ServerError.new("Invalid JSON in stream chunk: #{e.message}", status_code: nil)
              end
            end
          end
        end

        # Check for non-200 status codes
        handle_stream_response_status(response)

        nil
      rescue Faraday::Error => e
        raise ServerError.new("Network error during streaming: #{e.message}", status_code: nil)
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

      def handle_stream_response_status(response)
        case response.status
        when 200..299
          # Success - streaming completed
        when 400
          raise InvalidRequestError.new(extract_error_message(response), status_code: 400)
        when 401, 403
          raise AuthenticationError.new("Invalid API key. Get one at https://makersuite.google.com/app/apikey", status_code: response.status)
        when 404
          raise InvalidRequestError.new("Resource not found. Check model name and endpoint.", status_code: 404)
        when 429
          raise RateLimitError.new(extract_error_message(response), status_code: 429)
        when 500..599
          raise ServerError.new(extract_error_message(response), status_code: response.status)
        else
          raise ApiError.new("Unexpected status code: #{response.status}", status_code: response.status)
        end
      end
    end
  end
end
