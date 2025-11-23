# frozen_string_literal: true

RSpec.describe Aigen::Google::Chat do
  let(:api_key) { "test-api-key" }
  let(:client) { Aigen::Google::Client.new(api_key: api_key, model: "gemini-pro") }
  let(:chat) { client.start_chat }

  describe "#initialize" do
    it "initializes with empty history by default" do
      expect(chat.history).to eq([])
    end

    it "initializes with provided history" do
      initial_history = [
        {role: "user", parts: [{text: "Hello"}]},
        {role: "model", parts: [{text: "Hi there!"}]}
      ]
      chat_with_history = client.start_chat(history: initial_history)
      expect(chat_with_history.history).to eq(initial_history)
    end

    it "creates a copy of the provided history" do
      initial_history = [{role: "user", parts: [{text: "Hello"}]}]
      chat_with_history = client.start_chat(history: initial_history)

      # Verify initial history wasn't modified by adding messages via send_message
      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
        .to_return(
          status: 200,
          body: {
            "candidates" => [{
              "content" => {"parts" => [{"text" => "Hi"}], "role" => "model"}
            }]
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      chat_with_history.send_message("Test")
      expect(initial_history.length).to eq(1)
      expect(chat_with_history.history.length).to eq(3)
    end
  end

  describe "#send_message" do
    let(:api_response) do
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [{"text" => "Hello! How can I help you?"}],
              "role" => "model"
            },
            "finishReason" => "STOP"
          }
        ]
      }
    end

    before do
      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
        .to_return(status: 200, body: api_response.to_json, headers: {"Content-Type" => "application/json"})
    end

    it "sends a message and returns response" do
      response = chat.send_message("Hi")
      expect(response["candidates"][0]["content"]["parts"][0]["text"]).to eq("Hello! How can I help you?")
    end

    it "updates history with user message" do
      chat.send_message("Hi")
      user_message = chat.history.find { |msg| msg[:role] == "user" }
      expect(user_message[:parts][0][:text]).to eq("Hi")
    end

    it "updates history with model response" do
      chat.send_message("Hi")
      model_message = chat.history.find { |msg| msg[:role] == "model" }
      expect(model_message[:parts][0]["text"]).to eq("Hello! How can I help you?")
    end

    it "includes previous messages in API request for context" do
      chat.send_message("Hi")

      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
        .with(body: hash_including({
          "contents" => array_including(
            hash_including({"role" => "user", "parts" => [{"text" => "Hi"}]}),
            hash_including({"role" => "model"}),
            hash_including({"role" => "user", "parts" => [{"text" => "Follow-up"}]})
          )
        }))
        .to_return(status: 200, body: api_response.to_json, headers: {"Content-Type" => "application/json"})

      chat.send_message("Follow-up")
    end

    it "maintains history across multiple messages" do
      chat.send_message("First message")

      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
        .to_return(status: 200, body: api_response.to_json, headers: {"Content-Type" => "application/json"})

      chat.send_message("Second message")

      expect(chat.history.length).to eq(4) # 2 user + 2 model messages
      expect(chat.history[0][:parts][0][:text]).to eq("First message")
      expect(chat.history[2][:parts][0][:text]).to eq("Second message")
    end

    it "handles empty model response gracefully" do
      empty_response = {
        "candidates" => [
          {
            "content" => {
              "parts" => [],
              "role" => "model"
            }
          }
        ]
      }

      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
        .to_return(status: 200, body: empty_response.to_json, headers: {"Content-Type" => "application/json"})

      chat.send_message("Test")
      expect(chat.history.length).to eq(2)
      expect(chat.history[1][:role]).to eq("model")
    end

    it "raises ArgumentError when message is nil" do
      expect {
        chat.send_message(nil)
      }.to raise_error(ArgumentError, "message cannot be nil")
    end

    it "raises ArgumentError when message is empty string" do
      expect {
        chat.send_message("")
      }.to raise_error(ArgumentError, "message cannot be empty")
    end
  end

  describe "#history" do
    it "returns empty array for new chat" do
      expect(chat.history).to eq([])
    end

    it "returns all messages in correct format" do
      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
        .to_return(
          status: 200,
          body: {
            "candidates" => [
              {
                "content" => {
                  "parts" => [{"text" => "Response 1"}],
                  "role" => "model"
                }
              }
            ]
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      chat.send_message("Message 1")

      history = chat.history
      expect(history.length).to eq(2)
      expect(history[0]).to include(role: "user", parts: [{text: "Message 1"}])
      expect(history[1]).to include(role: "model", parts: [hash_including("text" => "Response 1")])
    end

    it "returns a frozen copy to prevent external mutation" do
      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
        .to_return(
          status: 200,
          body: {
            "candidates" => [
              {
                "content" => {
                  "parts" => [{"text" => "Response"}],
                  "role" => "model"
                }
              }
            ]
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      chat.send_message("Test")
      history = chat.history

      expect(history).to be_frozen
      expect {
        history << {role: "user", parts: [{text: "Hacked"}]}
      }.to raise_error(FrozenError)
    end
  end

  describe "chat with initial history" do
    let(:initial_history) do
      [
        {role: "user", parts: [{text: "Previous message"}]},
        {role: "model", parts: [{text: "Previous response"}]}
      ]
    end

    let(:chat_with_context) { client.start_chat(history: initial_history) }

    it "includes initial history in first API request" do
      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
        .with(body: hash_including({
          "contents" => array_including(
            hash_including({"role" => "user", "parts" => [{"text" => "Previous message"}]}),
            hash_including({"role" => "model", "parts" => [{"text" => "Previous response"}]}),
            hash_including({"role" => "user", "parts" => [{"text" => "New message"}]})
          )
        }))
        .to_return(
          status: 200,
          body: {
            "candidates" => [
              {
                "content" => {
                  "parts" => [{"text" => "New response"}],
                  "role" => "model"
                }
              }
            ]
          }.to_json,
          headers: {"Content-Type" => "application/json"}
        )

      chat_with_context.send_message("New message")
      expect(chat_with_context.history.length).to eq(4)
    end
  end

  describe "#send_message_stream" do
    let(:chat) { client.start_chat }

    context "with block given" do
      it "yields progressive chunks to the block" do
        chunks = [
          {candidates: [{content: {parts: [{text: "Hello"}], role: "model"}}]},
          {candidates: [{content: {parts: [{text: " there"}], role: "model"}}]},
          {candidates: [{content: {parts: [{text: "!"}], role: "model"}}]}
        ]
        chunk_data = chunks.map { |c| "#{c.to_json}\n" }.join

        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent")
          .to_return(status: 200, body: chunk_data)

        received_texts = []
        chat.send_message_stream("Hi") do |chunk|
          received_texts << chunk["candidates"][0]["content"]["parts"][0]["text"]
        end

        expect(received_texts).to eq(["Hello", " there", "!"])
      end

      it "updates history with full accumulated response after streaming completes" do
        chunks = [
          {candidates: [{content: {parts: [{text: "Hello"}], role: "model"}}]},
          {candidates: [{content: {parts: [{text: " world"}], role: "model"}}]}
        ]
        chunk_data = chunks.map { |c| "#{c.to_json}\n" }.join

        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent")
          .to_return(status: 200, body: chunk_data)

        expect(chat.history.length).to eq(0)

        chat.send_message_stream("Hi") { |chunk| }

        expect(chat.history.length).to eq(2)
        expect(chat.history[0][:role]).to eq("user")
        expect(chat.history[0][:parts][0][:text]).to eq("Hi")
        expect(chat.history[1][:role]).to eq("model")
        expect(chat.history[1][:parts][0]["text"]).to eq("Hello world")
      end

      it "maintains conversation context across multiple streaming messages" do
        # First streaming message
        chunks1 = [
          {candidates: [{content: {parts: [{text: "Hello"}], role: "model"}}]}
        ]
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent")
          .with(body: hash_including({
            contents: array_including(
              hash_including({"role" => "user", "parts" => [{"text" => "Hi"}]})
            )
          }))
          .to_return(status: 200, body: chunks1.map { |c| "#{c.to_json}\n" }.join)

        chat.send_message_stream("Hi") { |chunk| }

        # Second streaming message should include first in history
        chunks2 = [
          {candidates: [{content: {parts: [{text: "Good"}], role: "model"}}]}
        ]
        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent")
          .with(body: hash_including({
            contents: array_including(
              hash_including({"role" => "user", "parts" => [{"text" => "Hi"}]}),
              hash_including({"role" => "model", "parts" => [{"text" => "Hello"}]}),
              hash_including({"role" => "user", "parts" => [{"text" => "How are you?"}]})
            )
          }))
          .to_return(status: 200, body: chunks2.map { |c| "#{c.to_json}\n" }.join)

        chat.send_message_stream("How are you?") { |chunk| }

        expect(chat.history.length).to eq(4)
      end

      it "returns nil when block is given" do
        chunk_data = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hi\"}]}}]}\n"

        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent")
          .to_return(status: 200, body: chunk_data)

        result = chat.send_message_stream("Test") { |chunk| }
        expect(result).to be_nil
      end

      it "validates message parameter" do
        expect {
          chat.send_message_stream(nil) { |chunk| }
        }.to raise_error(ArgumentError, "message cannot be nil")

        expect {
          chat.send_message_stream("") { |chunk| }
        }.to raise_error(ArgumentError, "message cannot be empty")
      end
    end

    context "without block (Enumerator)" do
      it "returns an Enumerator" do
        chunk_data = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hi\"}]}}]}\n"

        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent")
          .to_return(status: 200, body: chunk_data)

        result = chat.send_message_stream("Test")
        expect(result).to be_a(Enumerator)
      end

      it "updates history after enumerator is consumed" do
        chunks = [
          {candidates: [{content: {parts: [{text: "One"}], role: "model"}}]},
          {candidates: [{content: {parts: [{text: "Two"}], role: "model"}}]}
        ]
        chunk_data = chunks.map { |c| "#{c.to_json}\n" }.join

        stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:streamGenerateContent")
          .to_return(status: 200, body: chunk_data)

        enum = chat.send_message_stream("Test")
        expect(chat.history.length).to eq(0)

        enum.to_a

        expect(chat.history.length).to eq(2)
        expect(chat.history[1][:parts][0]["text"]).to eq("OneTwo")
      end
    end
  end
end
