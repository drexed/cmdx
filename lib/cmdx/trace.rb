# frozen_string_literal: true

module CMDx
  # Correlates nested task executions without thread-local globals.
  class Trace

    # @return [String]
    attr_reader :id

    # @return [Trace, nil]
    attr_reader :parent

    # @param id [String]
    # @param parent [Trace, nil]
    def initialize(id:, parent: nil)
      @id = id
      @parent = parent
    end

    # @param id_generator [Proc]
    # @return [Trace]
    def self.root(id_generator: nil)
      gen = id_generator || CMDx.configuration.id_generator
      new(id: gen.call)
    end

    # @return [Trace]
    def child(id_generator: CMDx.configuration.id_generator)
      self.class.new(id: id_generator.call, parent: self)
    end

  end
end
