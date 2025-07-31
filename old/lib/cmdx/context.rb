# frozen_string_literal: true

module CMDx
  # Execution context container for task parameter storage and access.
  #
  # Context provides normalized parameter storage for task execution, inheriting
  # from LazyStruct to provide flexible attribute access patterns. It serves as
  # the primary interface for storing and retrieving execution parameters, allowing
  # both hash-style and method-style attribute access with automatic key normalization.
  # Context instances are used throughout task execution to maintain parameter state
  # and provide consistent data access across the task lifecycle.
  class Context < LazyStruct

    # Creates or returns a Context instance from the provided input.
    #
    # This factory method normalizes various input types into a proper Context instance,
    # ensuring consistent context handling throughout the framework. If the input is
    # already a Context instance and not frozen, it returns the input unchanged to
    # avoid unnecessary object creation. Otherwise, it creates a new Context instance
    # with the provided data.
    #
    # @param context [Hash, Context, Object] input data to convert to Context
    # @option context [Object] any any attribute keys and values for context initialization
    #
    # @return [Context] a Context instance containing the provided data
    #
    # @example Create context from hash
    #   context = Context.build(user_id: 123, action: "process")
    #   context.user_id #=> 123
    #   context.action #=> "process"
    #
    # @example Return existing unfrozen context
    #   existing = Context.new(status: "active")
    #   result = Context.build(existing)
    #   result.equal?(existing) #=> true
    #
    # @example Create new context from frozen context
    #   frozen_context = Context.new(data: "test").freeze
    #   new_context = Context.build(frozen_context)
    #   new_context.equal?(frozen_context) #=> false
    #   new_context.data #=> "test"
    #
    # @example Create context from empty input
    #   context = Context.build
    #   context.class #=> CMDx::Context
    #   context.to_h #=> {}
    def self.build(context = {})
      return context if context.is_a?(self) && !context.frozen?

      new(context)
    end

  end
end
