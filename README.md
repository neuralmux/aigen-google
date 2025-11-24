# Aigen::Google

Ruby SDK for Google's Gemini API - build AI-powered applications with text generation, chat, streaming, and multimodal content support.

[![Gem Version](https://badge.fury.io/rb/aigen-google.svg)](https://badge.fury.io/rb/aigen-google)
[![Build Status](https://github.com/neuralmux/aigen-google/workflows/CI/badge.svg)](https://github.com/neuralmux/aigen-google/actions)

## Features

- **Text Generation:** Generate content from text prompts
- **Chat with History:** Multi-turn conversations with context preservation
- **Streaming:** Real-time response delivery with progressive chunks
- **Multimodal Content:** Combine text and images in requests
- **Generation Config:** Control output with temperature, top_p, top_k, max_output_tokens
- **Safety Settings:** Configure content filtering for harm categories
- **Comprehensive Error Handling:** Automatic retries with exponential backoff for rate limits and server errors
- **Ruby 3.1+ Support:** Modern Ruby idioms with frozen string literals

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'aigen-google'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install aigen-google
```

## Quick Start

```ruby
require 'aigen/google'

# Configure with your API key
Aigen::Google.configure do |config|
  config.api_key = ENV['GOOGLE_API_KEY']
end

# Generate content
client = Aigen::Google::Client.new
response = client.generate_content(prompt: "Explain quantum computing in simple terms")
puts response["candidates"][0]["content"]["parts"][0]["text"]
```

## Configuration

### Block-based Configuration (Recommended)

```ruby
Aigen::Google.configure do |config|
  config.api_key = ENV['GOOGLE_API_KEY']
  config.default_model = "gemini-pro"
  config.timeout = 60
end

client = Aigen::Google::Client.new
```

### Instance-based Configuration

```ruby
client = Aigen::Google::Client.new(
  api_key: "your-api-key",
  model: "gemini-pro",
  timeout: 60
)
```

### Available Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `api_key` | String | `ENV['GOOGLE_API_KEY']` | Your Google AI API key ([Get one here](https://makersuite.google.com/app/apikey)) |
| `default_model` | String | `"gemini-pro"` | Default model to use for requests |
| `timeout` | Integer | `30` | HTTP request timeout in seconds |
| `retry_count` | Integer | `3` | Number of retry attempts for rate limits/server errors |

## Usage Examples

### Basic Text Generation

```ruby
client = Aigen::Google::Client.new

response = client.generate_content(prompt: "Write a haiku about Ruby programming")
text = response["candidates"][0]["content"]["parts"][0]["text"]
puts text
```

### Chat with History

```ruby
chat = client.start_chat

# First message
chat.send_message("What is Ruby?")

# Follow-up with context
response = chat.send_message("What are its main features?")
text = response["candidates"][0]["content"]["parts"][0]["text"]
puts text

# View conversation history
puts chat.history
```

### Streaming Responses

Stream responses as they're generated for real-time feedback:

```ruby
# With block (immediate processing)
client.generate_content_stream(prompt: "Tell me a story") do |chunk|
  text = chunk["candidates"][0]["content"]["parts"][0]["text"]
  print text
end

# With Enumerator (lazy evaluation)
stream = client.generate_content_stream(prompt: "Count to 10")
stream.each do |chunk|
  text = chunk["candidates"][0]["content"]["parts"][0]["text"]
  print text
end
```

### Chat Streaming

```ruby
chat = client.start_chat

chat.send_message_stream("Tell me a joke") do |chunk|
  text = chunk["candidates"][0]["content"]["parts"][0]["text"]
  print text
end
# History is updated after streaming completes
```

### Multimodal Content (Text + Images)

```ruby
require 'base64'

# Prepare image data
image_data = Base64.strict_encode64(File.read("photo.jpg"))

# Create multimodal content
text_content = Aigen::Google::Content.text("What is in this image?")
image_content = Aigen::Google::Content.image(
  data: image_data,
  mime_type: "image/jpeg"
)

# Generate content with both
response = client.generate_content(contents: [text_content.to_h, image_content.to_h])
text = response["candidates"][0]["content"]["parts"][0]["text"]
puts text
```

### Configuring Generation Parameters

Control output quality and randomness:

```ruby
response = client.generate_content(
  prompt: "Write a creative story",
  temperature: 0.9,      # Higher = more creative (0.0-1.0)
  top_p: 0.95,           # Nucleus sampling (0.0-1.0)
  top_k: 40,             # Top-k sampling
  max_output_tokens: 1024 # Maximum response length
)
```

### Safety Settings

Configure content filtering:

```ruby
# Use default settings (BLOCK_MEDIUM_AND_ABOVE for all categories)
settings = Aigen::Google::SafetySettings.default

# Or customize
settings = Aigen::Google::SafetySettings.new([
  {
    category: Aigen::Google::SafetySettings::HARM_CATEGORY_HATE_SPEECH,
    threshold: Aigen::Google::SafetySettings::BLOCK_LOW_AND_ABOVE
  },
  {
    category: Aigen::Google::SafetySettings::HARM_CATEGORY_DANGEROUS_CONTENT,
    threshold: Aigen::Google::SafetySettings::BLOCK_MEDIUM_AND_ABOVE
  }
])

response = client.generate_content(
  prompt: "Hello",
  safety_settings: settings.to_h
)
```

## Error Handling

The SDK provides comprehensive error handling with automatic retries:

### Exception Types

| Exception | When Raised | Retry Behavior |
|-----------|-------------|----------------|
| `Aigen::Google::AuthenticationError` | Invalid API key (401/403) | No retry |
| `Aigen::Google::InvalidRequestError` | Malformed request (400/404) | No retry |
| `Aigen::Google::RateLimitError` | Rate limit exceeded (429) | Automatic retry with backoff |
| `Aigen::Google::ServerError` | Server error (500-599) | Automatic retry with backoff |
| `Aigen::Google::TimeoutError` | Request timeout | Automatic retry with backoff |
| `Aigen::Google::ApiError` | Other API errors | No retry |

### Retry Behavior

The SDK automatically retries rate limit (429) and server errors (500-599) with exponential backoff:
- **Attempt 1:** Wait 1 second, retry
- **Attempt 2:** Wait 2 seconds, retry
- **Attempt 3:** Wait 4 seconds, raise error if fails

Maximum retry attempts: 3 (configurable via `retry_count`)

### Handling Errors

```ruby
begin
  response = client.generate_content(prompt: "Hello")
rescue Aigen::Google::AuthenticationError => e
  puts "Invalid API key: #{e.message}"
  puts "Get your API key at: https://makersuite.google.com/app/apikey"
rescue Aigen::Google::RateLimitError => e
  puts "Rate limit exceeded: #{e.message}"
  puts "Try reducing request rate or increasing quota"
rescue Aigen::Google::ServerError => e
  puts "Server error (#{e.status_code}): #{e.message}"
  puts "Try again later - the API may be experiencing issues"
rescue Aigen::Google::TimeoutError => e
  puts "Request timed out: #{e.message}"
rescue Aigen::Google::ApiError => e
  puts "API error (#{e.status_code}): #{e.message}"
end
```

## API Reference

Full API documentation is available at [https://rubydoc.info/gems/aigen-google](https://rubydoc.info/gems/aigen-google) (YARD documentation).

### Key Classes

- `Aigen::Google::Client` - Main client for API requests
- `Aigen::Google::Chat` - Multi-turn conversation management
- `Aigen::Google::Content` - Multimodal content builder
- `Aigen::Google::GenerationConfig` - Generation parameter configuration
- `Aigen::Google::SafetySettings` - Content filtering configuration
- `Aigen::Google::Configuration` - Global configuration

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with coverage report
COVERAGE=true bundle exec rspec

# Run linter
bundle exec rake standard

# Run both tests and linter
bundle exec rake
```

### Code Quality

- **Test Coverage:** >= 90% (enforced with SimpleCov)
- **Code Style:** StandardRB (0 offenses required)
- **Ruby Version:** >= 3.1.0

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/neuralmux/aigen-google.

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

## Resources

- [Gemini API Documentation](https://ai.google.dev/docs)
- [Get your API Key](https://makersuite.google.com/app/apikey)
- [Ruby Style Guide](https://rubystyle.guide/)
- [YARD Documentation Guide](https://rubydoc.info/gems/yard/file/docs/GettingStarted.md)
