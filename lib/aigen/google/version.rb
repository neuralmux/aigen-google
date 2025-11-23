# frozen_string_literal: true

module Aigen
  module Google
    def self.gem_version
      Gem::Version.new(VERSION::STRING)
    end

    module VERSION
      MAJOR = 0
      MINOR = 1
      TINY = 0
      PRE = nil
      BUILD = nil
      STRING = [MAJOR, MINOR, TINY, PRE, BUILD].compact.join(".")
    end
  end
end
