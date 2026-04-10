# frozen_string_literal: true

module CMDx
  module Utils
    module Format

      # Converts a class name to a type string (e.g. "Users::CreateUser" -> "users/create_user").
      #
      # @param klass [Class]
      # @return [String]
      #
      # @rbs (Class klass) -> String
      def self.type_name(klass)
        name = klass.name || klass.to_s
        name.gsub("::", "/")
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .downcase
      end

    end
  end
end
