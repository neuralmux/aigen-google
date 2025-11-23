# frozen_string_literal: true

require_relative "lib/aigen/google/version"

Gem::Specification.new do |spec|
  spec.name = "aigen-google"
  spec.version = Aigen::Google.gem_version
  spec.authors = ["Lauri Jutila"]
  spec.email = ["ljuti@nmux.dev"]

  spec.summary = "Ruby SDK for Google Generative AI (Gemini API)"
  spec.description = "A Ruby-native SDK for Google's Generative AI (Gemini) APIs, providing text generation, chat, streaming, and multimodal content support."
  spec.homepage = "https://github.com/neuralmux/aigen-google"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/neuralmux/aigen-google"
  spec.metadata["changelog_uri"] = "https://github.com/neuralmux/aigen-google/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Production dependencies
  spec.add_dependency "faraday", "~> 2.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
