# frozen_string_literal: true

module Aigen
  module Google
    class Configuration
      attr_accessor :api_key, :default_model, :timeout, :retry_count

      def initialize
        @api_key = ENV.fetch("GOOGLE_API_KEY", nil)
        @default_model = "gemini-pro"
        @timeout = 30
        @retry_count = 3
      end

      def validate!
        raise ConfigurationError, "API key is required. Set via Aigen::Google.configure or ENV['GOOGLE_API_KEY']" if api_key.nil? || api_key.empty?
      end
    end
  end
end
