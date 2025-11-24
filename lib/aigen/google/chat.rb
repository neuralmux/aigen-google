# frozen_string_literal: true

module Aigen
  module Google
    # Chat manages stateful multi-turn conversations with the Gemini API.
    # It maintains conversation history and automatically includes context
    # in each API request for coherent, context-aware responses.
    #
    # @example Starting a new chat session
    #   client = Aigen::Google::Client.new(api_key: "your-api-key")
    #   chat = client.start_chat
    #   response = chat.send_message("Hello!")
    #   puts response["candidates"][0]["content"]["parts"][0]["text"]
    #
    # @example Multi-turn conversation with context
    #   chat = client.start_chat
    #   chat.send_message("What is Ruby?")
    #   chat.send_message("What are its main features?") # Uses context from first message
    #   puts chat.history # View full conversation
    #
    # @example Starting chat with existing history
    #   history = [
    #     {role: "user", parts: [{text: "Hello"}]},
    #     {role: "model", parts: [{text: "Hi there!"}]}
    #   ]
    #   chat = client.start_chat(history: history)
    #   chat.send_message("How are you?") # Continues from existing context
    class Chat
      # Returns the conversation history as an array of message hashes.
      # Each message has a role ("user" or "model") and parts array.
      #
      # @return [Array<Hash>] a frozen copy of the conversation history
      # @note The returned array is frozen to prevent external modification.
      #   The history is managed internally by the Chat instance.
      def history
        @history.dup.freeze
      end

      # Initializes a new Chat instance.
      #
      # @param client [Aigen::Google::Client] the client instance for API requests
      # @param model [String, nil] the model to use (defaults to client's default_model)
      # @param history [Array<Hash>] initial conversation history (defaults to empty array)
      #
      # @example Create a new chat
      #   chat = Chat.new(client: client, model: "gemini-pro")
      #
      # @example Create chat with existing history
      #   history = [{role: "user", parts: [{text: "Hello"}]}]
      #   chat = Chat.new(client: client, history: history)
      def initialize(client:, model: nil, history: [])
        @client = client
        @model = model || @client.config.default_model
        @history = history.dup
      end

      # Sends a message in the chat context and returns the model's response.
      # Automatically includes conversation history for context and updates
      # history with both the user message and model response.
      #
      # Accepts both simple String messages and Content objects for multimodal support.
      #
      # @param message [String, Content] the message text or Content object to send
      # @param options [Hash] additional options to pass to the API (e.g., generationConfig)
      #
      # @return [Hash] the API response containing the model's reply
      #
      # @raise [Aigen::Google::AuthenticationError] if API key is invalid
      # @raise [Aigen::Google::InvalidRequestError] if the request is malformed
      # @raise [Aigen::Google::RateLimitError] if rate limit is exceeded
      # @raise [Aigen::Google::ServerError] if the API returns a server error
      # @raise [Aigen::Google::TimeoutError] if the request times out
      # @raise [ArgumentError] if message is nil or empty
      #
      # @example Send a simple text message
      #   response = chat.send_message("What is the weather today?")
      #   text = response["candidates"][0]["content"]["parts"][0]["text"]
      #
      # @example Send multimodal content (text + image)
      #   content = Aigen::Google::Content.new([
      #     {text: "What is in this image?"},
      #     {inline_data: {mime_type: "image/jpeg", data: base64_data}}
      #   ])
      #   response = chat.send_message(content)
      #
      # @example Send message with generation config
      #   response = chat.send_message(
      #     "Tell me a story",
      #     generationConfig: {temperature: 0.9, maxOutputTokens: 1024}
      #   )
      def send_message(message, **options)
        # Validate message parameter
        raise ArgumentError, "message cannot be nil" if message.nil?
        raise ArgumentError, "message cannot be empty" if message.respond_to?(:empty?) && message.empty?

        # Build user message part
        # Handle both String (simple text) and Content objects (multimodal)
        user_message = if message.is_a?(Content)
          # Content object - use its to_h serialization and add role
          message.to_h.merge(role: "user")
        else
          # String - wrap in standard format
          {
            role: "user",
            parts: [{text: message}]
          }
        end

        # Build payload with full history + new message
        payload = {
          contents: @history + [user_message]
        }

        # Merge any additional generation config options
        payload.merge!(options) if options.any?

        # Make API request
        endpoint = "models/#{@model}:generateContent"
        response = @client.http_client.post(endpoint, payload)

        # Extract model response
        model_response = extract_model_message(response)

        # Update history with both user message and model response
        @history << user_message
        @history << model_response

        response
      end

      # Sends a message in the chat context with streaming response delivery.
      # Automatically includes conversation history for context and updates history
      # with the full accumulated response after streaming completes.
      #
      # @param message [String] the message text to send
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
      # @raise [ArgumentError] if message is nil or empty
      #
      # @note The conversation history is NOT updated until the entire stream completes.
      #   This ensures the history remains consistent even if streaming is interrupted.
      #
      # @example Stream chat response with block
      #   chat = client.start_chat
      #   chat.send_message_stream("Tell me a joke") do |chunk|
      #     text = chunk["candidates"][0]["content"]["parts"][0]["text"]
      #     print text
      #   end
      #   # History now contains both user message and full accumulated response
      #
      # @example Stream with Enumerator for lazy processing
      #   chat = client.start_chat
      #   stream = chat.send_message_stream("Count to 5")
      #   stream.each { |chunk| puts chunk["candidates"][0]["content"]["parts"][0]["text"] }
      #   puts chat.history.length # => 2 (user + model)
      def send_message_stream(message, **options, &block)
        # Validate message parameter
        raise ArgumentError, "message cannot be nil" if message.nil?
        raise ArgumentError, "message cannot be empty" if message.respond_to?(:empty?) && message.empty?

        # Build user message part
        user_message = {
          role: "user",
          parts: [{text: message}]
        }

        # Build payload with full history + new message
        payload = {
          contents: @history + [user_message]
        }

        # Merge any additional generation config options
        payload.merge!(options) if options.any?

        # Make API request
        endpoint = "models/#{@model}:streamGenerateContent"

        # Accumulate full response text while streaming
        accumulated_text = ""

        # If block given, stream with block and accumulate
        if block_given?
          @client.http_client.post_stream(endpoint, payload) do |chunk|
            # Extract text from chunk
            text = extract_chunk_text(chunk)
            accumulated_text += text if text

            # Yield chunk to user's block
            block.call(chunk)
          end

          # After streaming completes, update history with full response
          update_history_after_stream(user_message, accumulated_text)
          nil
        else
          # Return Enumerator that accumulates and updates history when consumed
          Enumerator.new do |yielder|
            @client.http_client.post_stream(endpoint, payload) do |chunk|
              text = extract_chunk_text(chunk)
              accumulated_text += text if text
              yielder << chunk
            end

            # Update history after enumeration completes
            update_history_after_stream(user_message, accumulated_text)
          end
        end
      end

      private

      def extract_model_message(response)
        candidate = response.dig("candidates", 0)
        return {role: "model", parts: [{text: ""}]} unless candidate

        content = candidate["content"]
        return {role: "model", parts: [{text: ""}]} unless content

        {
          role: content["role"] || "model",
          parts: content["parts"] || [{text: ""}]
        }
      end

      def extract_chunk_text(chunk)
        chunk.dig("candidates", 0, "content", "parts", 0, "text")
      end

      def update_history_after_stream(user_message, accumulated_text)
        # Add user message to history
        @history << user_message

        # Add accumulated model response to history (using symbol keys like non-streaming)
        model_response = {
          role: "model",
          parts: [{"text" => accumulated_text}]
        }
        @history << model_response
      end
    end
  end
end
