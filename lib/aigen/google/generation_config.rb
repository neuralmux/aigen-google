# frozen_string_literal: true

module Aigen
  module Google
    # GenerationConfig controls generation parameters for the Gemini API.
    # Validates parameter ranges and raises InvalidRequestError before API calls.
    #
    # @example Basic configuration
    #   config = Aigen::Google::GenerationConfig.new(temperature: 0.7, max_output_tokens: 1024)
    #   config.to_h # => {temperature: 0.7, maxOutputTokens: 1024}
    #
    # @example All parameters
    #   config = Aigen::Google::GenerationConfig.new(
    #     temperature: 0.9,
    #     top_p: 0.95,
    #     top_k: 40,
    #     max_output_tokens: 2048
    #   )
    class GenerationConfig
      # Initializes a GenerationConfig instance with optional parameters.
      # Validates all parameters and raises InvalidRequestError if invalid.
      #
      # @param temperature [Float, nil] controls randomness (0.0-1.0)
      # @param top_p [Float, nil] nucleus sampling threshold (0.0-1.0)
      # @param top_k [Integer, nil] top-k sampling limit (> 0)
      # @param max_output_tokens [Integer, nil] maximum response tokens (> 0)
      # @param response_modalities [Array<String>, nil] output modalities: ["TEXT"], ["IMAGE"], or ["TEXT", "IMAGE"]
      # @param aspect_ratio [String, nil] image aspect ratio: "1:1", "16:9", "9:16", "4:3", "3:4", "5:4", "4:5"
      # @param image_size [String, nil] image resolution: "1K", "2K", "4K" (uppercase required)
      #
      # @raise [InvalidRequestError] if any parameter is out of valid range
      #
      # @example
      #   config = GenerationConfig.new(temperature: 0.5)
      #
      # @example Image generation
      #   config = GenerationConfig.new(
      #     response_modalities: ["TEXT", "IMAGE"],
      #     aspect_ratio: "16:9",
      #     image_size: "2K"
      #   )
      def initialize(temperature: nil, top_p: nil, top_k: nil, max_output_tokens: nil, response_modalities: nil, aspect_ratio: nil, image_size: nil)
        validate_temperature(temperature) if temperature
        validate_top_p(top_p) if top_p
        validate_top_k(top_k) if top_k
        validate_max_output_tokens(max_output_tokens) if max_output_tokens
        validate_response_modalities(response_modalities) if response_modalities
        validate_aspect_ratio(aspect_ratio) if aspect_ratio
        validate_image_size(image_size) if image_size

        @temperature = temperature
        @top_p = top_p
        @top_k = top_k
        @max_output_tokens = max_output_tokens
        @response_modalities = response_modalities
        @aspect_ratio = aspect_ratio
        @image_size = image_size
      end

      # Serializes the configuration to Gemini API format with camelCase keys.
      # Omits nil values from the output.
      #
      # @return [Hash] the configuration hash with camelCase keys
      #
      # @example
      #   config = GenerationConfig.new(temperature: 0.7, max_output_tokens: 1024)
      #   config.to_h # => {temperature: 0.7, maxOutputTokens: 1024}
      def to_h
        result = {}
        result[:temperature] = @temperature unless @temperature.nil?
        result[:topP] = @top_p unless @top_p.nil?
        result[:topK] = @top_k unless @top_k.nil?
        result[:maxOutputTokens] = @max_output_tokens unless @max_output_tokens.nil?
        result[:responseModalities] = @response_modalities unless @response_modalities.nil?

        # Image generation parameters go under imageConfig
        if @aspect_ratio || @image_size
          image_config = {}
          image_config[:aspectRatio] = @aspect_ratio unless @aspect_ratio.nil?
          image_config[:imageSize] = @image_size unless @image_size.nil?
          result[:imageConfig] = image_config
        end

        result
      end

      private

      def validate_temperature(value)
        unless value.between?(0.0, 1.0)
          raise InvalidRequestError.new(
            "temperature must be between 0.0 and 1.0, got #{value}",
            status_code: nil
          )
        end
      end

      def validate_top_p(value)
        unless value.between?(0.0, 1.0)
          raise InvalidRequestError.new(
            "top_p must be between 0.0 and 1.0, got #{value}",
            status_code: nil
          )
        end
      end

      def validate_top_k(value)
        unless value > 0
          raise InvalidRequestError.new(
            "top_k must be greater than 0, got #{value}",
            status_code: nil
          )
        end
      end

      def validate_max_output_tokens(value)
        unless value > 0
          raise InvalidRequestError.new(
            "max_output_tokens must be greater than 0, got #{value}",
            status_code: nil
          )
        end
      end

      def validate_response_modalities(value)
        unless value.is_a?(Array)
          raise InvalidRequestError.new(
            "response_modalities must be an array",
            status_code: nil
          )
        end

        if value.empty?
          raise InvalidRequestError.new(
            "response_modalities must not be empty",
            status_code: nil
          )
        end

        valid_modalities = ["TEXT", "IMAGE"]
        invalid = value - valid_modalities
        unless invalid.empty?
          raise InvalidRequestError.new(
            "response_modalities must only contain TEXT or IMAGE, got: #{invalid.join(", ")}",
            status_code: nil
          )
        end
      end

      def validate_aspect_ratio(value)
        valid_ratios = ["1:1", "16:9", "9:16", "4:3", "3:4", "5:4", "4:5"]
        unless valid_ratios.include?(value)
          raise InvalidRequestError.new(
            "aspect_ratio must be one of #{valid_ratios.join(", ")}, got #{value}",
            status_code: nil
          )
        end
      end

      def validate_image_size(value)
        valid_sizes = ["1K", "2K", "4K"]
        unless valid_sizes.include?(value)
          raise InvalidRequestError.new(
            "image_size must be one of #{valid_sizes.join(", ")}, got #{value}",
            status_code: nil
          )
        end
      end
    end
  end
end
