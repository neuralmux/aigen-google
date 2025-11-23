# frozen_string_literal: true

module Aigen
  module Google
    class Client
      attr_reader :config

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
