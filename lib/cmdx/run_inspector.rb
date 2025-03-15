# frozen_string_literal: true

module CMDx
  module RunInspector

    FOOTER_KEYS = %i[
      state status outcome runtime
    ].freeze

    module_function

    def call(run)
      header = "\nrun: #{run.id}"
      footer = FOOTER_KEYS.map { |key| "#{key}: #{run.send(key)}" }.join(" | ")
      spacer = "=" * [header.size, footer.size].max

      run
        .results
        .map { |r| r.to_h.except(:run_id).pretty_inspect }
        .unshift(header, "#{spacer}\n")
        .push(spacer, "#{footer}\n\n")
        .join("\n")
    end

  end
end
