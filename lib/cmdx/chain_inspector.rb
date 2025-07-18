# frozen_string_literal: true

module CMDx
  # Provides formatted inspection and display functionality for chain execution results.
  #
  # ChainInspector creates human-readable string representations of execution chains,
  # displaying chain metadata, individual task results, and execution summary information
  # in a formatted layout. The inspector processes chain data to provide comprehensive
  # debugging and monitoring output for task execution sequences.
  module ChainInspector

    FOOTER_KEYS = %i[
      state status outcome runtime
    ].freeze

    module_function

    # Formats a chain into a human-readable inspection string with headers, results, and summary.
    #
    # Creates a comprehensive string representation of the execution chain including
    # a header with the chain ID, formatted individual task results, and a footer
    # summary with key execution metadata. The output uses visual separators for
    # clear section delineation and consistent formatting.
    #
    # @param chain [Chain] the execution chain to format and inspect
    #
    # @return [String] formatted multi-line string representation of the chain execution
    #
    # @example Format a simple chain
    #   chain = MyWorkflow.call(user_id: 123)
    #   output = ChainInspector.call(chain.chain)
    #   puts output
    #   # =>
    #   # chain: abc123-def456-789
    #   # ===============================
    #   #
    #   # {:task=>"MyTask", :state=>"complete", :status=>"success"}
    #   # {:task=>"OtherTask", :state=>"complete", :status=>"success"}
    #   #
    #   # ===============================
    #   # state: complete | status: success | outcome: good | runtime: 0.025
    def call(chain)
      header = "\nchain: #{chain.id}"
      footer = FOOTER_KEYS.map { |key| "#{key}: #{chain.send(key)}" }.join(" | ")
      spacer = "=" * [header.size, footer.size].max

      chain
        .results
        .map { |r| r.to_h.except(:chain_id).pretty_inspect }
        .unshift(header, "#{spacer}\n")
        .push(spacer, "#{footer}\n\n")
        .join("\n")
    end

  end
end
