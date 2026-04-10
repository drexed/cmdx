# frozen_string_literal: true

module CMDx
  # Output contract validation. Declares expected context keys that must
  # be present after successful task execution.
  module Returns

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@returns, returns_keys.dup)
      end

      # Declare expected return keys.
      #
      # @param keys [Array<Symbol>]
      # @return [void]
      def returns(*keys)
        returns_keys.concat(keys.map(&:to_sym))
      end

      # Remove inherited return declarations.
      #
      # @param keys [Array<Symbol>]
      # @return [void]
      def remove_returns(*keys)
        keys.each { |k| returns_keys.delete(k.to_sym) }
      end

      # @return [Array<Symbol>]
      def returns_keys
        @returns_keys ||= []
      end

    end

    private

    # Validate that all declared returns are present in the context.
    # Only runs when the result is still successful.
    #
    # @return [void]
    def validate_returns!
      return unless result.success?

      all_keys = self.class.returns_keys + (self.class.task_settings.returns_keys || [])
      return if all_keys.empty?

      all_keys.uniq.each do |key|
        errors.add(key, Messages.resolve("return.missing")) unless context.key?(key)
      end

      return if errors.empty?

      result.fail!(Messages.resolve("halt.invalid"),
                   errors: { full_message: errors.to_s, messages: errors.to_h })
    end

  end
end
