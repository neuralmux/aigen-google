# frozen_string_literal: true

module Aigen
  module Google
    # Content represents text, image, or multimodal content for Gemini API requests.
    # Provides builder methods for creating content and serialization to API format.
    #
    # @example Text content
    #   content = Aigen::Google::Content.text("Hello, world!")
    #   content.to_h # => {parts: [{text: "Hello, world!"}]}
    #
    # @example Image content (Base64-encoded)
    #   require "base64"
    #   image_data = Base64.strict_encode64(File.read("image.jpg"))
    #   content = Aigen::Google::Content.image(data: image_data, mime_type: "image/jpeg")
    #   content.to_h # => {parts: [{inline_data: {mime_type: "image/jpeg", data: "..."}}]}
    #
    # @example Multimodal content (text + image)
    #   text_part = {text: "What is in this image?"}
    #   image_part = {inline_data: {mime_type: "image/jpeg", data: base64_data}}
    #   content = Aigen::Google::Content.new([text_part, image_part])
    class Content
      # Creates a text content instance.
      #
      # @param text [String] the text content
      # @return [Content] a Content instance with text part
      #
      # @example
      #   content = Content.text("Hello!")
      #   content.to_h # => {parts: [{text: "Hello!"}]}
      def self.text(text)
        new([{text: text}])
      end

      # Creates an image content instance with Base64-encoded data.
      #
      # @param data [String] Base64-encoded image data (use Base64.strict_encode64)
      # @param mime_type [String] the MIME type (e.g., "image/jpeg", "image/png")
      # @return [Content] a Content instance with inline_data part
      #
      # @example
      #   require "base64"
      #   data = Base64.strict_encode64(File.read("photo.jpg"))
      #   content = Content.image(data: data, mime_type: "image/jpeg")
      def self.image(data:, mime_type:)
        new([{
          inline_data: {
            mime_type: mime_type,
            data: data
          }
        }])
      end

      # Initializes a Content instance with an array of parts.
      #
      # @param parts [Array<Hash>] array of content parts
      #   - Text part: {text: "string"}
      #   - Image part: {inline_data: {mime_type: "...", data: "..."}}
      #
      # @example
      #   parts = [
      #     {text: "Describe this image:"},
      #     {inline_data: {mime_type: "image/jpeg", data: base64_data}}
      #   ]
      #   content = Content.new(parts)
      def initialize(parts)
        @parts = parts
      end

      # Serializes the content to Gemini API format.
      #
      # @return [Hash] the content hash with parts array
      #
      # @example
      #   content = Content.text("Hello")
      #   content.to_h # => {parts: [{text: "Hello"}]}
      def to_h
        {parts: @parts}
      end
    end
  end
end
