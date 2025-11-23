# frozen_string_literal: true

require_relative "google/version"
require_relative "google/errors"
require_relative "google/configuration"
require_relative "google/http_client"
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
