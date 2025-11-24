# frozen_string_literal: true

module Aigen
  module Google
    # SafetySettings configures content filtering for the Gemini API.
    # Provides constants for harm categories and thresholds, with sensible defaults.
    #
    # @example Using default settings (BLOCK_MEDIUM_AND_ABOVE for all categories)
    #   settings = Aigen::Google::SafetySettings.default
    #
    # @example Custom settings
    #   settings = Aigen::Google::SafetySettings.new([
    #     {
    #       category: Aigen::Google::SafetySettings::HARM_CATEGORY_HATE_SPEECH,
    #       threshold: Aigen::Google::SafetySettings::BLOCK_LOW_AND_ABOVE
    #     }
    #   ])
    class SafetySettings
      # Harm category constants
      HARM_CATEGORY_HATE_SPEECH = "HARM_CATEGORY_HATE_SPEECH"
      HARM_CATEGORY_DANGEROUS_CONTENT = "HARM_CATEGORY_DANGEROUS_CONTENT"
      HARM_CATEGORY_HARASSMENT = "HARM_CATEGORY_HARASSMENT"
      HARM_CATEGORY_SEXUALLY_EXPLICIT = "HARM_CATEGORY_SEXUALLY_EXPLICIT"

      # Threshold constants
      BLOCK_NONE = "BLOCK_NONE"
      BLOCK_LOW_AND_ABOVE = "BLOCK_LOW_AND_ABOVE"
      BLOCK_MEDIUM_AND_ABOVE = "BLOCK_MEDIUM_AND_ABOVE"
      BLOCK_ONLY_HIGH = "BLOCK_ONLY_HIGH"

      # Returns default safety settings with BLOCK_MEDIUM_AND_ABOVE for all categories.
      #
      # @return [Array<Hash>] array of default safety settings
      #
      # @example
      #   defaults = SafetySettings.default
      #   # => [
      #   #   {category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE"},
      #   #   {category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE"},
      #   #   ...
      #   # ]
      def self.default
        [
          {category: HARM_CATEGORY_HATE_SPEECH, threshold: BLOCK_MEDIUM_AND_ABOVE},
          {category: HARM_CATEGORY_DANGEROUS_CONTENT, threshold: BLOCK_MEDIUM_AND_ABOVE},
          {category: HARM_CATEGORY_HARASSMENT, threshold: BLOCK_MEDIUM_AND_ABOVE},
          {category: HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: BLOCK_MEDIUM_AND_ABOVE}
        ]
      end

      # Initializes a SafetySettings instance with an array of settings.
      #
      # @param settings [Array<Hash>] array of safety settings
      #   Each setting: {category: "HARM_CATEGORY_...", threshold: "BLOCK_..."}
      #
      # @example
      #   settings = SafetySettings.new([
      #     {category: HARM_CATEGORY_HATE_SPEECH, threshold: BLOCK_LOW_AND_ABOVE}
      #   ])
      def initialize(settings)
        @settings = settings
      end

      # Serializes the safety settings to Gemini API format.
      #
      # @return [Array<Hash>] the settings array in API format
      #
      # @example
      #   settings = SafetySettings.new([
      #     {category: HARM_CATEGORY_HATE_SPEECH, threshold: BLOCK_MEDIUM_AND_ABOVE}
      #   ])
      #   settings.to_h # => [{category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE"}]
      def to_h
        @settings
      end
    end
  end
end
