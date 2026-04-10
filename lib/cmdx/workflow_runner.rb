# frozen_string_literal: true

module CMDx
  # Runs {Workflow} pipeline groups (sequential or parallel) with breakpoints.
  module WorkflowRunner

    # @param session [Session]
    # @return [void]
    def self.run(session)
      handler = session.handler
      definition = handler.class.definition
      default_bps = Utils::Normalize.statuses(definition.workflow_breakpoints).map(&:to_sym)

      definition.workflow_pipeline.each do |group|
        tasks = group[:tasks]
        opts = group[:options]
        next unless Utils::Condition.evaluate(handler, opts)

        breakpoints = breakpoint_symbols(opts, default_bps)
        strategy = opts[:strategy]

        if parallel?(strategy)
          run_parallel(session, tasks, opts, breakpoints)
        else
          run_sequential(session, tasks, breakpoints)
        end
      end
    end

    # @param strategy [Object]
    # @return [Boolean]
    def self.parallel?(strategy)
      strategy.to_s == "parallel"
    end

    # @param opts [Hash]
    # @param defaults [Array<Symbol>]
    # @return [Array<Symbol>]
    def self.breakpoint_symbols(opts, defaults)
      if opts.key?(:breakpoints)
        Utils::Normalize.statuses(opts[:breakpoints]).map(&:to_sym)
      else
        defaults
      end
    end

    # @param session [Session]
    # @param tasks [Array<Class>]
    # @param breakpoints [Array<Symbol>]
    # @return [void]
    def self.run_sequential(session, tasks, breakpoints)
      handler = session.handler
      tasks.each do |task_class|
        sub = task_class.execute(session.context.to_h, trace: session.trace)
        session.context.merge!(sub.context.to_h)
        next unless breakpoints.include?(sub.status)

        handler.session.outcome.propagate_from!(sub.outcome, halt: true)
      end
    end

    # @param session [Session]
    # @param tasks [Array<Class>]
    # @param opts [Hash]
    # @param breakpoints [Array<Symbol>]
    # @return [void]
    def self.run_parallel(session, tasks, opts, breakpoints)
      handler = session.handler
      contexts = tasks.map { |_t| Context.new(session.context.to_h) }
      pairs = tasks.zip(contexts)
      pool = opts.fetch(:pool_size, pairs.size)

      results = Parallel::Threads.call(pairs, concurrency: pool) do |task_class, ctx|
        task_class.execute(ctx.to_h, trace: session.trace)
      end

      contexts.each { |ctx| session.context.merge!(ctx.to_h) }

      faulted = results.select { |r| breakpoints.include?(r.status) }
      return if faulted.empty?

      last = faulted.last
      handler.session.outcome.propagate_from!(last.outcome, halt: true)
    end

  end
end
