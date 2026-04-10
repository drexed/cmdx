# frozen_string_literal: true

module CMDx
  # Generates unique identifiers for tasks and chains.
  #
  # Uses SecureRandom.uuid for globally unique IDs.
  module Identifier

    # Generates a new unique identifier string.
    #
    # @return [String] a UUID string
    #
    # @example
    #   Identifier.generate # => "550e8400-e29b-41d4-a716-446655440000"
    #
    # @rbs () -> String
    def self.generate
      SecureRandom.uuid
    end

  end
end
