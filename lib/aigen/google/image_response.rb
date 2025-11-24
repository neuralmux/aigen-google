# frozen_string_literal: true

require "base64"

module Aigen
  module Google
    # Wraps an image generation API response with convenient helper methods.
    # Provides easy access to generated images, text descriptions, and status information.
    #
    # @example Basic usage
    #   response = client.generate_image("A cute puppy")
    #   if response.success?
    #     response.save("puppy.png")
    #     puts response.text
    #   end
    #
    # @example Checking for failures
    #   response = client.generate_image("problematic prompt")
    #   unless response.success?
    #     puts "Failed: #{response.failure_reason}"
    #     puts response.failure_message
    #   end
    class ImageResponse
      attr_reader :raw_response

      # Creates a new ImageResponse from a Gemini API response.
      #
      # @param response [Hash] the raw API response hash
      def initialize(response)
        @raw_response = response
      end

      # Checks if the image generation was successful.
      #
      # @return [Boolean] true if generation succeeded, false otherwise
      def success?
        finish_reason == "STOP"
      end

      # Checks if an image is present in the response.
      #
      # @return [Boolean] true if image data exists, false otherwise
      def has_image?
        !image_part.nil?
      end

      # Returns the text description that accompanied the generated image.
      #
      # @return [String, nil] the text description or nil if not present
      def text
        text_part&.dig("text")
      end

      # Returns the decoded binary image data.
      #
      # @return [String, nil] binary image data or nil if no image present
      def image_data
        return nil unless has_image?

        Base64.decode64(image_part["inlineData"]["data"])
      end

      # Returns the MIME type of the generated image.
      #
      # @return [String, nil] MIME type (e.g., "image/png") or nil if no image
      def mime_type
        image_part&.dig("inlineData", "mimeType")
      end

      # Saves the generated image to the specified file path.
      #
      # @param path [String] the file path to save the image
      # @raise [Aigen::Google::Error] if no image data is present
      #
      # @example
      #   response.save("output.png")
      def save(path)
        raise Error, "No image data to save" unless has_image?

        File.write(path, image_data)
      end

      # Returns the finish reason for failed generations.
      #
      # @return [String, nil] the finish reason or nil if successful
      def failure_reason
        return nil if success?

        candidate.dig("finishReason")
      end

      # Returns the failure message for failed generations.
      #
      # @return [String, nil] the failure message or nil if successful
      def failure_message
        return nil if success?

        candidate.dig("finishMessage")
      end

      private

      def candidate
        @raw_response.dig("candidates", 0) || {}
      end

      def parts
        candidate.dig("content", "parts") || []
      end

      def text_part
        parts.find { |p| p.key?("text") }
      end

      def image_part
        parts.find { |p| p.key?("inlineData") }
      end

      def finish_reason
        candidate.dig("finishReason")
      end
    end
  end
end
