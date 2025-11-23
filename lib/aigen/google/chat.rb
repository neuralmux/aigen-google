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
      # @param message [String] the message text to send
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
      # @example Send a message
      #   response = chat.send_message("What is the weather today?")
      #   text = response["candidates"][0]["content"]["parts"][0]["text"]
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
        endpoint = "models/#{@model}:generateContent"
        response = @client.http_client.post(endpoint, payload)

        # Extract model response
        model_response = extract_model_message(response)

        # Update history with both user message and model response
        @history << user_message
        @history << model_response

        response
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
    end
  end
end
