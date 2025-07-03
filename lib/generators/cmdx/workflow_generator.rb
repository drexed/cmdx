# frozen_string_literal: true

module Cmdx
  ##
  # Rails generator for creating CMDx workflow task classes.
  #
  # This generator creates workflow task files that coordinate multiple
  # individual tasks in a structured workflow. Workflow tasks inherit
  # from CMDx::Workflow and provide orchestration capabilities for
  # complex business processes.
  #
  # The generator handles name normalization, ensuring proper file naming
  # conventions and class names. Generated workflow tasks inherit from
  # ApplicationWorkflow when available, falling back to CMDx::Workflow.
  #
  # @example Generate a workflow task
  #   rails generate cmdx:workflow OrderProcessing
  #   rails generate cmdx:workflow PaymentWorkflow  # "Workflow" suffix preserved
  #
  # @example Generated file location
  #   app/cmds/order_processing_workflow.rb
  #   app/cmds/payment_workflow.rb
  #
  # @example Generated class structure
  #   class OrderProcessingWorkflow < ApplicationWorkflow
  #     def call
  #       # Workflow orchestration logic
  #     end
  #   end
  #
  # @see CMDx::Workflow Base workflow class
  # @see Rails::Generators::NamedBase Rails generator base class
  # @since 1.0.0
  class WorkflowGenerator < Rails::Generators::NamedBase

    source_root File.expand_path("templates", __dir__)
    check_class_collision suffix: "Workflow"

    desc "Creates a workflow with the given NAME"

    ##
    # Copies the workflow task template to the application commands directory.
    #
    # Creates a new workflow task file in `app/cmds/` with the normalized
    # name. The generator automatically handles:
    # - Removing "workflow" suffix from the provided name for filename
    # - Converting to snake_case for file naming
    # - Adding "_workflow" suffix to the filename
    # - Setting up proper class inheritance
    # - Ensuring class names end with "Workflow"
    #
    # @return [void]
    # @raise [Thor::Error] if the destination file cannot be created
    #
    # @example File generation
    #   # Input: rails generate cmdx:workflow OrderProcessing
    #   # Creates: app/cmds/order_processing_workflow.rb
    #   # Class: OrderProcessingWorkflow
    #
    #   # Input: rails generate cmdx:workflow PaymentWorkflow
    #   # Creates: app/cmds/payment_workflow.rb
    #   # Class: PaymentWorkflow
    def copy_files
      name = file_name.sub(/_?workflow$/i, "")
      path = File.join("app/cmds", class_path, "#{name}_workflow.rb")
      template("workflow.rb.tt", path)
    end

    private

    ##
    # Normalizes the class name by ensuring it ends with "Workflow".
    #
    # Ensures consistent class naming by appending "Workflow" suffix
    # to the provided generator name if it doesn't already end with it,
    # allowing users to specify either "OrderProcessing" or "OrderProcessingWorkflow".
    #
    # @return [String] the normalized class name with "Workflow" suffix
    #
    # @example Class name normalization
    #   # Input: "OrderProcessing"
    #   # Output: "OrderProcessingWorkflow"
    #
    #   # Input: "PaymentWorkflow"
    #   # Output: "PaymentWorkflow"
    def class_name
      @class_name ||= super.end_with?("Workflow") ? super : "#{super}Workflow"
    end

    ##
    # Determines the parent class for the generated workflow task.
    #
    # Attempts to use ApplicationWorkflow as the parent class if available,
    # falling back to CMDx::Workflow if ApplicationWorkflow is not defined.
    # This allows applications to define custom base workflow behavior.
    #
    # @return [String] the parent class name to inherit from
    #
    # @example Parent class resolution
    #   # If ApplicationWorkflow exists: "ApplicationWorkflow"
    #   # If ApplicationWorkflow missing: "CMDx::Workflow"
    def parent_class_name
      ApplicationWorkflow
    rescue StandardError
      CMDx::Workflow
    end

  end
end
