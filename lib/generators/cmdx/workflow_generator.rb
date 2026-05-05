# frozen_string_literal: true

module Cmdx
  # Rails generator that scaffolds a new {CMDx::Workflow} subclass under
  # `app/tasks`, honoring nested module paths supplied through the NAME
  # argument (e.g. `Billing::Checkout` writes to
  # `app/tasks/billing/checkout.rb`).
  #
  # Invoked via `rails generate cmdx:workflow NAME`.
  #
  # @see CMDx::Workflow
  class WorkflowGenerator < Rails::Generators::NamedBase

    source_root File.expand_path("templates", __dir__)

    desc "Creates a workflow with the given NAME"

    # Renders `workflow.rb.tt` into `app/tasks/<class_path>/<file_name>.rb`.
    #
    # @return [void]
    def copy_files
      path = File.join("app/tasks", class_path, "#{file_name}.rb")
      template("workflow.rb.tt", path)
    end

    private

    # Selects the parent class for the generated workflow: prefers the host
    # application's `ApplicationTask` when defined, falling back to
    # {CMDx::Task} otherwise. Consumed by the ERB template via `<%= %>`.
    #
    # @return [Class] either `ApplicationTask` or {CMDx::Task}
    def parent_class_name
      ApplicationTask
    rescue NameError
      CMDx::Task
    end

  end
end
