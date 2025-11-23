# frozen_string_literal: true

require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<GOOGLE_API_KEY>") { ENV.fetch("GOOGLE_API_KEY", "test-api-key") }
  config.configure_rspec_metadata!
  config.default_cassette_options = {
    record: :none,
    match_requests_on: [:method, :uri, :body]
  }
  # Allow real connections during manual VCR recording only
  config.allow_http_connections_when_no_cassette = false
end
