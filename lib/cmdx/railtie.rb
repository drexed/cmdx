# frozen_string_literal: true

module CMDx
  ##
  # Railtie provides seamless integration between CMDx and Ruby on Rails applications.
  # It automatically configures Rails-specific features including internationalization,
  # autoloading paths, and directory structure conventions for CMDx tasks and batches.
  #
  # The Railtie handles two main integration aspects:
  # 1. **I18n Configuration**: Automatically loads CMDx locale files for available locales
  # 2. **Autoloading Setup**: Configures Rails autoloaders for CMDx command objects
  #
  # ## Directory Structure
  #
  # The Railtie expects CMDx command objects to be organized in the following structure:
  # ```
  # app/
  #   cmds/
  #     batches/          # Batch command objects
  #       order_processing_batch.rb
  #     tasks/            # Task command objects
  #       process_order_task.rb
  #       send_email_task.rb
  # ```
  #
  # ## Automatic Features
  #
  # When CMDx is included in a Rails application, the Railtie automatically:
  # - Adds `app/cmds` to Rails autoload paths
  # - Configures autoloader to collapse `app/cmds/batches` and `app/cmds/tasks` directories
  # - Loads appropriate locale files from CMDx gem for error messages and validations
  # - Reloads I18n configuration to include CMDx translations
  #
  # @example Rails application structure
  #   # app/cmds/tasks/process_order_task.rb
  #   class ProcessOrderTask < CMDx::Task
  #     required :order_id, type: :integer
  #
  #     def call
  #       context.order = Order.find(order_id)
  #       context.order.process!
  #     end
  #   end
  #
  # @example Using in Rails controllers
  #   class OrdersController < ApplicationController
  #     def process
  #       result = ProcessOrderTask.call(order_id: params[:id])
  #
  #       if result.success?
  #         redirect_to order_path(result.context.order), notice: 'Order processed!'
  #       else
  #         redirect_to order_path(params[:id]), alert: result.metadata[:reason]
  #       end
  #     end
  #   end
  #
  # @example I18n integration
  #   # CMDx automatically loads locale files for validation messages
  #   # en.yml, es.yml, etc. are automatically available
  #   result = MyTask.call(invalid_param: nil)
  #   result.errors.full_messages # Uses localized error messages
  #
  # @see Configuration Configuration options for Rails integration
  # @see Task Task base class for command objects
  # @see Batch Batch base class for multi-task operations
  # @since 0.6.0
  class Railtie < Rails::Railtie

    railtie_name :cmdx

    ##
    # Configures internationalization (I18n) for CMDx in Rails applications.
    # Automatically loads locale files from the CMDx gem for all configured
    # application locales, ensuring error messages and validations are properly localized.
    #
    # This initializer:
    # 1. Iterates through all configured application locales
    # 2. Checks for corresponding CMDx locale files
    # 3. Adds found locale files to I18n load path
    # 4. Reloads I18n configuration
    #
    # @param app [Rails::Application] the Rails application instance
    # @return [void]
    #
    # @example Available locales
    #   # If Rails app has config.i18n.available_locales = [:en, :es]
    #   # This will load:
    #   # - lib/locales/en.yml (CMDx English translations)
    #   # - lib/locales/es.yml (CMDx Spanish translations)
    #
    # @example Localized error messages
    #   # With Spanish locale active
    #   class MyTask < CMDx::Task
    #     required :name, presence: true
    #   end
    #
    #   result = MyTask.call(name: "")
    #   result.errors.full_messages # Returns Spanish error messages
    initializer("cmdx.configure_locales") do |app|
      Array(app.config.i18n.available_locales).each do |locale|
        path = File.expand_path("../../../lib/locales/#{locale}.yml", __FILE__)
        next unless File.file?(path)

        I18n.load_path << path
      end

      I18n.reload!
    end

    ##
    # Configures Rails autoloading for CMDx command objects.
    # Sets up proper autoloading paths and directory collapsing to ensure
    # CMDx tasks and batches are loaded correctly in Rails applications.
    #
    # This initializer:
    # 1. Adds `app/cmds` to Rails autoload paths
    # 2. Configures all autoloaders to collapse concept directories
    # 3. Ensures proper class name resolution for nested directories
    #
    # Directory collapsing means that files in `app/cmds/tasks/` will be loaded
    # as if they were directly in `app/cmds/`, allowing for better organization
    # without affecting class naming conventions.
    #
    # @param app [Rails::Application] the Rails application instance
    # @return [void]
    #
    # @example Directory structure and class loading
    #   # File: app/cmds/tasks/process_order_task.rb
    #   # Class: ProcessOrderTask (not Tasks::ProcessOrderTask)
    #
    #   # File: app/cmds/batches/order_processing_batch.rb
    #   # Class: OrderProcessingBatch (not Batches::OrderProcessingBatch)
    #
    # @example Autoloading in action
    #   # Rails will automatically load these classes when referenced:
    #   ProcessOrderTask.call(order_id: 123)      # Loads from app/cmds/tasks/
    #   OrderProcessingBatch.call(orders: [...])  # Loads from app/cmds/batches/
    initializer("cmdx.configure_rails_auto_load_paths") do |app|
      app.config.autoload_paths += %w[app/cmds]

      types = %w[batches tasks]
      app.autoloaders.each do |autoloader|
        types.each do |concept|
          dir = app.root.join("app/cmds/#{concept}")
          autoloader.collapse(dir)
        end
      end
    end

  end
end
