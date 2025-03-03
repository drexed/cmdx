# frozen_string_literal: true

module Cmdx
  class BatchGenerator < Rails::Generators::NamedBase

    source_root File.expand_path("../templates", __FILE__)
    check_class_collision suffix: "Batch"

    def copy_files
      path = File.join("app/cmds", class_path, "batch_#{file_name}.rb")
      template("batch.rb.tt", path)
    end

    private

    def file_name
      @_file_name ||= remove_possible_prefix(super)
    end

    def remove_possible_prefix(name)
      name.sub(/^batch_?/i, "")
    end

  end
end
