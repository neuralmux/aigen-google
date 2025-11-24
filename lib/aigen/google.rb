# frozen_string_literal: true

require_relative "google/version"
require_relative "google/errors"
require_relative "google/configuration"
require_relative "google/content"
require_relative "google/generation_config"
require_relative "google/safety_settings"
require_relative "google/http_client"
require_relative "google/image_response"
require_relative "google/chat"
require_relative "google/client"

module Aigen
  module Google
    class << self
      attr_accessor :configuration

      def configure
        self.configuration ||= Configuration.new
        yield(configuration) if block_given?
        configuration
      end
    end
  end
end
