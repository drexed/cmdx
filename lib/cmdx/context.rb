# frozen_string_literal: true

module CMDx
  # Parameter and data context for task execution.
  #
  # Context provides flexible data storage and access patterns for task
  # parameters and runtime data. Built on LazyStruct, it supports both
  # hash-like and object-like access patterns with dynamic attribute
  # assignment and automatic key normalization.
  class Context < LazyStruct

    # Creates or returns a context instance from the given input.
    #
    # This method provides a safe way to build context instances, returning
    # the input unchanged if it's already a Context instance and not frozen,
    # otherwise creating a new Context instance with the provided data.
    #
    # @param context [Hash, Context, Object] input data to build context from
    #
    # @return [Context] a Context instance containing the provided data
    #
    # @raise [ArgumentError] if the input doesn't respond to to_h
    #
    # @example Build context from hash
    #   Context.build(name: "John", age: 30)
    #   #=> #<CMDx::Context :name="John" :age=30>
    #
    # @example Build context from existing context
    #   existing = Context.build(user_id: 123)
    #   Context.build(existing)
    #   #=> returns existing context unchanged
    #
    # @example Build context from hash-like object
    #   Context.build(OpenStruct.new(status: "active"))
    #   #=> #<CMDx::Context :status="active">
    def self.build(context = {})
      return context if context.is_a?(self) && !context.frozen?

      new(context)
    end

  end
end
