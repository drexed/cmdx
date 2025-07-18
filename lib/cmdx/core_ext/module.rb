# frozen_string_literal: true

module CMDx
  module CoreExt
    # Extensions for Ruby's Module class that provide attribute delegation and settings functionality.
    # These extensions are automatically included in all modules when CMDx is loaded.
    module ModuleExtensions

      # Creates delegated methods that forward calls to another object or class.
      # Supports method name prefixing, privacy levels, and optional method existence checking.
      #
      # @param methods [Array<Symbol>] the method names to delegate
      # @param options [Hash] delegation options
      # @option options [Symbol] :to the target object or :class to delegate to
      # @option options [Boolean] :allow_missing (false) whether to allow delegation to non-existent methods
      # @option options [Boolean] :protected (false) whether to make the delegated method protected
      # @option options [Boolean] :private (false) whether to make the delegated method private
      # @option options [String, Symbol] :prefix optional prefix for the delegated method name
      # @option options [String, Symbol] :suffix optional suffix for the delegated method name
      #
      # @return [void]
      # @raise [NoMethodError] when delegating to a non-existent method and :allow_missing is false
      #
      # @example Delegate methods to an instance variable
      #   class Task
      #     def initialize
      #       @logger = Logger.new
      #     end
      #
      #     cmdx_attr_delegator :info, :warn, :error, to: :@logger
      #   end
      #
      # @example Delegate with prefix and privacy
      #   class Workflow
      #     cmdx_attr_delegator :perform, to: :task, prefix: 'execute_', private: true
      #   end
      def cmdx_attr_delegator(*methods, **options)
        methods.each do |method|
          method_name = Utils::NameAffix.call(method, options.fetch(:to), options)

          define_method(method_name) do |*args, **kwargs, &block|
            object = (options[:to] == :class ? self.class : send(options[:to]))

            unless options[:allow_missing] || object.respond_to?(method, true)
              raise NoMethodError,
                    "undefined method `#{method}' for #{options[:to]}"
            end

            object.send(method, *args, **kwargs, &block)
          end

          case options
          in { protected: true } then send(:protected, method_name)
          in { private: true } then send(:private, method_name)
          else # Leave public
          end
        end
      end

      # Creates a singleton method for accessing inheritable settings with caching and default values.
      # Settings are inherited from superclass and can have default values via blocks or static values.
      #
      # @param method [Symbol] the name of the setting method to create
      # @param options [Hash] setting options
      # @option options [Object, Proc] :default the default value or a proc that returns the default value
      #
      # @return [void]
      #
      # @example Define a setting with a default value
      #   class BaseTask
      #     cmdx_attr_setting :timeout, default: 30
      #   end
      #
      #   BaseTask.timeout #=> 30
      #
      # @example Define a setting with a dynamic default
      #   class Task
      #     cmdx_attr_setting :retry_count, default: -> { ENV['RETRY_COUNT']&.to_i || 3 }
      #   end
      def cmdx_attr_setting(method, **options)
        define_singleton_method(method) do
          @cmd_facets ||= {}
          return @cmd_facets[method] if @cmd_facets.key?(method)

          value = superclass.cmdx_try(method)
          return @cmd_facets[method] = value.dup unless value.nil?

          default = options[:default]
          value   = default.cmdx_call
          @cmd_facets[method] = default.is_a?(Proc) ? value : value.dup
        end
      end

    end
  end
end

Module.include(CMDx::CoreExt::ModuleExtensions)
