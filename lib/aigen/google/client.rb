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

      # Generates content from the Gemini API with support for text, multimodal content,
      # generation parameters, and safety settings.
      #
      # @param prompt [String, nil] simple text prompt (for backward compatibility)
      # @param contents [Array<Hash>, nil] array of content hashes for multimodal requests
      # @param model [String, nil] the model to use (defaults to client's default_model)
      # @param temperature [Float, nil] controls randomness (0.0-1.0)
      # @param top_p [Float, nil] nucleus sampling threshold (0.0-1.0)
      # @param top_k [Integer, nil] top-k sampling limit (> 0)
      # @param max_output_tokens [Integer, nil] maximum response tokens (> 0)
      # @param safety_settings [Array<Hash>, nil] safety filtering configuration
      # @param options [Hash] additional options to pass to the API
      #
      # @return [Hash] the API response
      #
      # @raise [Aigen::Google::InvalidRequestError] if validation fails (before API call)
      # @raise [Aigen::Google::AuthenticationError] if API key is invalid
      # @raise [Aigen::Google::RateLimitError] if rate limit is exceeded
      # @raise [Aigen::Google::ServerError] if the API returns a server error
      #
      # @example Simple text prompt (backward compatible)
      #   response = client.generate_content(prompt: "Hello")
      #
      # @example With generation config
      #   response = client.generate_content(
      #     prompt: "Tell me a story",
      #     temperature: 0.7,
      #     max_output_tokens: 1024
      #   )
      #
      # @example Multimodal content (text + image)
      #   text = Aigen::Google::Content.text("What is in this image?")
      #   image = Aigen::Google::Content.image(data: base64_data, mime_type: "image/jpeg")
      #   response = client.generate_content(contents: [text.to_h, image.to_h])
      #
      # @example Image generation (Nano Banana)
      #   response = client.generate_content(
      #     prompt: "A serene mountain landscape",
      #     response_modalities: ["TEXT", "IMAGE"],
      #     aspect_ratio: "16:9",
      #     image_size: "2K"
      #   )
      def generate_content(prompt: nil, contents: nil, model: nil, temperature: nil, top_p: nil, top_k: nil, max_output_tokens: nil, response_modalities: nil, aspect_ratio: nil, image_size: nil, safety_settings: nil, **options)
        model ||= @config.default_model

        # Build generation config if parameters provided (validates before API call)
        gen_config = nil
        if temperature || top_p || top_k || max_output_tokens || response_modalities || aspect_ratio || image_size
          gen_config = GenerationConfig.new(
            temperature: temperature,
            top_p: top_p,
            top_k: top_k,
            max_output_tokens: max_output_tokens,
            response_modalities: response_modalities,
            aspect_ratio: aspect_ratio,
            image_size: image_size
          )
        end

        # Build payload
        payload = {}

        # Handle contents (multimodal) or prompt (simple text)
        if contents
          payload[:contents] = contents
        elsif prompt
          # Backward compatibility: convert simple prompt to contents format
          payload[:contents] = [
            {
              parts: [
                {text: prompt}
              ]
            }
          ]
        end

        # Add generation config if present
        payload[:generationConfig] = gen_config.to_h if gen_config && !gen_config.to_h.empty?

        # Add safety settings if present
        payload[:safetySettings] = safety_settings if safety_settings

        # Merge any additional options
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
