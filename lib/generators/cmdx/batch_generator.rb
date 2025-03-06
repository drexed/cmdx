# frozen_string_literal: true

module Cmdx
  class BatchGenerator < Rails::Generators::NamedBase

    source_root File.expand_path("templates", __dir__)
    check_class_collision prefix: "Batch"

    desc "Generates a batch task with the given NAME (if one does not exist)."

    def copy_files
      name = file_name.sub(/^batch_?/i, "")
      path = File.join("app/cmds", class_path, "batch_#{name}.rb")
      template("batch.rb.tt", path)
    end

    private

    def class_name
      @class_name ||= super.delete_prefix("Batch")
    end

    def parent_class_name
      ApplicationBatch
    rescue StandardError
      CMDx::Batch
    end

  end
end
