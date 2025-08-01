# frozen_string_literal: true

module CMDx
  module Utils
    module ID

      extend self

      def generate!
        if SecureRandom.respond_to?(:uuid_v7)
          SecureRandom.uuid_v7
        else
          SecureRandom.uuid
        end
      end

    end
  end
end
