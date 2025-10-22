# frozen_string_literal: true

module CMDx
  # Generates unique identifiers for tasks, workflows, and other CMDx components.
  #
  # The Identifier module provides a consistent way to generate unique identifiers
  # across the CMDx system, with fallback support for different Ruby versions.
  module Identifier

    extend self

    # Generates a unique identifier string.
    #
    # @return [String] A unique identifier string (UUID v7 if available, otherwise UUID v4)
    #
    # @raise [StandardError] If SecureRandom is unavailable or fails to generate an identifier
    #
    # @example Generate a unique identifier
    #   CMDx::Identifier.generate
    #   # => "01890b2c-1234-5678-9abc-def123456789"
    #
    # @rbs () -> String
    def generate
      if SecureRandom.respond_to?(:uuid_v7)
        SecureRandom.uuid_v7
      else
        SecureRandom.uuid
      end
    end

  end
end
