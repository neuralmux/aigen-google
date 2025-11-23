# frozen_string_literal: true

module Aigen
  module Google
    class Client
      attr_reader :config, :http_client

      def initialize(api_key: nil, model: nil, timeout: nil, **options)
        @config = build_configuration(api_key, model, timeout, options)
        @config.validate!
        @http_client = HttpClient.new(
          api_key: @config.api_key,
          timeout: @config.timeout,
          retry_count: @config.retry_count
        )
      end

      def generate_content(prompt:, model: nil, **options)
        model ||= @config.default_model

        payload = {
          contents: [
            {
              parts: [
                {text: prompt}
              ]
            }
          ]
        }

        # Merge any additional generation config options
        payload.merge!(options) if options.any?

        endpoint = "models/#{model}:generateContent"
        @http_client.post(endpoint, payload)
      end

      # Streams generated content from the Gemini API with progressive chunk delivery.
      # Supports both block-based immediate processing and lazy Enumerator evaluation.
      #
      # @param prompt [String] the prompt text to generate content from
      # @param model [String, nil] the model to use (defaults to client's default_model)
      # @param options [Hash] additional options to pass to the API (e.g., generationConfig)
      # @yieldparam chunk [Hash] parsed JSON chunk from the streaming response (if block given)
      #
      # @return [nil] if block is given, returns nil after streaming completes
      # @return [Enumerator] if no block given, returns lazy Enumerator for progressive iteration
      #
      # @raise [Aigen::Google::AuthenticationError] if API key is invalid
      # @raise [Aigen::Google::InvalidRequestError] if the request is malformed
      # @raise [Aigen::Google::RateLimitError] if rate limit is exceeded
      # @raise [Aigen::Google::ServerError] if the API returns a server error
      # @raise [Aigen::Google::TimeoutError] if the request times out
      #
      # @example Stream with block (immediate processing)
      #   client.generate_content_stream(prompt: "Tell me a story") do |chunk|
      #     text = chunk["candidates"][0]["content"]["parts"][0]["text"]
      #     print text
      #   end
      #
      # @example Stream with Enumerator (lazy evaluation)
      #   stream = client.generate_content_stream(prompt: "Tell me a story")
      #   stream.each do |chunk|
      #     text = chunk["candidates"][0]["content"]["parts"][0]["text"]
      #     print text
      #   end
      #
      # @example Stream with lazy operations
      #   stream = client.generate_content_stream(prompt: "Count to 10")
      #   first_three = stream.lazy.take(3).map { |c| c["candidates"][0]["content"]["parts"][0]["text"] }.to_a
      def generate_content_stream(prompt:, model: nil, **options, &block)
        model ||= @config.default_model

        payload = {
          contents: [
            {
              parts: [
                {text: prompt}
              ]
            }
          ]
        }

        # Merge any additional generation config options
        payload.merge!(options) if options.any?

        endpoint = "models/#{model}:streamGenerateContent"

        # If block given, stream with block
        if block_given?
          @http_client.post_stream(endpoint, payload, &block)
        else
          # Return Enumerator for lazy evaluation
          Enumerator.new do |yielder|
            @http_client.post_stream(endpoint, payload) do |chunk|
              yielder << chunk
            end
          end
        end
      end

      def start_chat(history: [], model: nil, **options)
        Chat.new(
          client: self,
          model: model || @config.default_model,
          history: history
        )
      end

      private

      def build_configuration(api_key, model, timeout, options)
        # Start with global configuration if available
        config = if Google.configuration
          Google.configuration.dup
        else
          Configuration.new
        end

        # Override with instance-specific values
        config.api_key = api_key if api_key
        config.default_model = model if model
        config.timeout = timeout if timeout
        options.each { |k, v| config.send("#{k}=", v) if config.respond_to?("#{k}=") }

        config
      end
    end
  end
end
