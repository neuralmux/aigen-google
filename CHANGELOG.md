# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-11-23

### Added

**Core Features:**
- Text generation with Gemini API (`Client#generate_content`)
- Multi-turn chat with conversation history (`Client#start_chat`, `Chat#send_message`)
- Streaming responses with progressive chunk delivery (`Client#generate_content_stream`, `Chat#send_message_stream`)
- Multimodal content support (text + images via `Content` class)
- Generation configuration (`GenerationConfig` with temperature, top_p, top_k, max_output_tokens)
- Safety settings with sensible defaults (`SafetySettings` with harm categories and thresholds)

**Configuration:**
- Global configuration via `Aigen::Google.configure` block
- Instance-level configuration via client initialization
- Environment variable fallback for API key (`GOOGLE_API_KEY`)
- Configurable timeout and retry count

**Error Handling:**
- Comprehensive exception hierarchy (`AuthenticationError`, `InvalidRequestError`, `RateLimitError`, `ServerError`, `TimeoutError`, `ApiError`)
- Automatic retry logic with exponential backoff (1s, 2s, 4s) for rate limits (429) and server errors (500-599)
- Client-side validation for generation config parameters (fail-fast approach)
- Helpful error messages with context and actionable suggestions

**Developer Experience:**
- YARD documentation for all public APIs with `@param`, `@return`, `@raise`, `@example` tags
- Frozen string literals for memory efficiency
- StandardRB compliance (0 offenses)
- Ruby 3.1+ support with modern idioms
- Comprehensive test suite (137 examples, >= 90% coverage)

**Testing & Quality:**
- RSpec test suite with 137 passing examples
- SimpleCov integration for coverage tracking
- WebMock for HTTP stubbing in tests
- StandardRB linter configuration
- Continuous integration ready

### Technical Details

**Architecture:**
- Clean separation of concerns: `Client` (orchestration), `Chat` (state), `HttpClient` (transport), `Content` (data), `GenerationConfig` (validation), `SafetySettings` (configuration)
- Builder pattern for Content creation (`.text()`, `.image()`)
- Fail-fast validation in GenerationConfig
- Enumerator pattern for lazy streaming evaluation
- History management with frozen copies to prevent external mutation

**API Compatibility:**
- Gemini API v1beta support
- Backward compatible prompt API alongside new contents API
- camelCase conversion for API parameters (maxOutputTokens, topP, topK)
- Newline-delimited JSON streaming (not traditional SSE)

### Dependencies

- `faraday` ~> 2.0 - HTTP client
- `rspec` ~> 3.0 - Testing framework (development)
- `webmock` ~> 3.0 - HTTP mocking (development)
- `standard` ~> 1.3 - Ruby linter (development)
- `simplecov` ~> 0.22 - Code coverage (development)

### Breaking Changes

None - this is the initial release.

### Known Issues

None

---

[Unreleased]: https://github.com/neuralmux/aigen-google/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/neuralmux/aigen-google/releases/tag/v0.1.0
