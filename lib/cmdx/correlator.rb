# frozen_string_literal: true

module CMDx
  module Correlator

    THREAD_KEY = :cmdx_correlation_id

    module_function

    def generate
      SecureRandom.uuid
    end

    def id
      Thread.current[THREAD_KEY]
    end

    def id=(value)
      Thread.current[THREAD_KEY] = value
    end

    def clear
      Thread.current[THREAD_KEY] = nil
    end

    def use(value)
      unless value.is_a?(String) || value.is_a?(Symbol)
        raise TypeError,
              "must be a String or Symbol"
      end

      previous_id = id
      self.id = value
      yield
    ensure
      self.id = previous_id
    end

  end
end
