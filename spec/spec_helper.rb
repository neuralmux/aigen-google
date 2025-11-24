# frozen_string_literal: true

# Coverage tracking (run with: COVERAGE=true bundle exec rspec)
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/vendor/"
    minimum_coverage 90
  end
end

require "aigen/google"
require "webmock/rspec"
# require "support/vcr"  # Disabled until we record real API interactions

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
