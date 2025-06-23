# frozen_string_literal: true

module Cmdx
  ##
  # Rails generator for creating CMDx batch task classes.
  #
  # This generator creates batch task files that coordinate multiple
  # individual tasks in a structured workflow. Batch tasks inherit
  # from CMDx::Batch and provide orchestration capabilities for
  # complex business processes.
  #
  # The generator handles name normalization, removing "Batch" prefixes
  # and ensuring proper file naming conventions. Generated batch tasks
  # inherit from ApplicationBatch when available, falling back to CMDx::Batch.
  #
  # @example Generate a batch task
  #   rails generate cmdx:batch OrderProcessing
  #   rails generate cmdx:batch BatchPayment  # "Batch" prefix removed
  #
  # @example Generated file location
  #   app/cmds/order_processing_batch.rb
  #   app/cmds/payment_batch.rb
  #
  # @since 0.6.0
  class BatchGenerator < Rails::Generators::NamedBase

    source_root File.expand_path("templates", __dir__)
    check_class_collision prefix: "Batch"

    desc "Creates a batch task with the given NAME"

    ##
    # Copies the batch task template to the application commands directory.
    #
    # Creates a new batch task file in `app/cmds/` with the normalized
    # name. The generator automatically handles:
    # - Removing "Batch" prefix from the provided name
    # - Converting to snake_case for file naming
    # - Adding "batch_" prefix to the filename
    # - Setting up proper class inheritance
    #
    # @return [void]
    # @raise [Thor::Error] if the destination file cannot be created
    #
    # @example Generated batch task structure
    #   class OrderProcessingBatch < ApplicationBatch
    #     def call
    #       # Batch orchestration logic
    #     end
    #   end
    def copy_files
      name = file_name.sub(/^batch_?/i, "")
      path = File.join("app/cmds", class_path, "batch_#{name}.rb")
      template("batch.rb.tt", path)
    end

    private

    ##
    # Normalizes the class name by removing "Batch" prefix.
    #
    # Ensures consistent class naming by removing any "Batch" prefix
    # from the provided generator name, allowing users to specify
    # either "OrderProcessing" or "BatchOrderProcessing".
    #
    # @return [String] the normalized class name without "Batch" prefix
    #
    # @example Class name normalization
    #   # Input: "BatchOrderProcessing"
    #   # Output: "OrderProcessing"
    #
    #   # Input: "OrderProcessing"
    #   # Output: "OrderProcessing"
    def class_name
      @class_name ||= super.delete_prefix("Batch")
    end

    ##
    # Determines the parent class for the generated batch task.
    #
    # Attempts to use ApplicationBatch as the parent class if available,
    # falling back to CMDx::Batch if ApplicationBatch is not defined.
    # This allows applications to define custom base batch behavior.
    #
    # @return [String] the parent class name to inherit from
    #
    # @example Parent class resolution
    #   # If ApplicationBatch exists: "ApplicationBatch"
    #   # If ApplicationBatch missing: "CMDx::Batch"
    def parent_class_name
      ApplicationBatch
    rescue StandardError
      CMDx::Batch
    end

  end
end
