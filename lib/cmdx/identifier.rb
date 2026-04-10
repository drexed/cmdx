# frozen_string_literal: true

module CMDx
  # Generates unique identifiers for tasks, chains, and traces.
  module Identifier

    # Uses UUID v7 when available (Ruby 3.3+), falls back to v4.
    #
    # @return [String]
    #
    # @rbs () -> String
    def self.generate
      if SecureRandom.respond_to?(:uuid_v7)
        SecureRandom.uuid_v7
      else
        SecureRandom.uuid
      end
    end

  end
end
