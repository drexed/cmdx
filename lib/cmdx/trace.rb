# frozen_string_literal: true

module CMDx
  # Correlates nested task executions without thread-local globals.
  # Each execution gets a Trace; child tasks in workflows get child traces.
  class Trace

    # @return [String]
    attr_reader :id

    # @return [Trace, nil]
    attr_reader :parent

    # @param id [String]
    # @param parent [Trace, nil]
    #
    # @rbs (id: String, ?parent: Trace?) -> void
    def initialize(id:, parent: nil)
      @id = id
      @parent = parent
    end

    # Creates a root trace with a fresh ID.
    #
    # @return [Trace]
    #
    # @rbs () -> Trace
    def self.root
      new(id: CMDx.configuration.id_generator.call)
    end

    # Creates a child trace linked to this one.
    #
    # @return [Trace]
    #
    # @rbs () -> Trace
    def child
      self.class.new(id: CMDx.configuration.id_generator.call, parent: self)
    end

    # @return [String, nil]
    #
    # @rbs () -> String?
    def parent_id
      @parent&.id
    end

  end
end
