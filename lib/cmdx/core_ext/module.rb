# frozen_string_literal: true

module CMDx
  module CoreExt
    # Extensions to Module that provide CMDx-specific metaprogramming capabilities.
    #
    # ModuleExtensions adds method delegation and attribute setting functionality
    # used throughout the CMDx framework. These methods enable declarative
    # programming patterns and automatic method generation.
    #
    # @example Method delegation
    #   class Task
    #     cmdx_attr_delegator :name, :email, to: :user
    #     cmdx_attr_delegator :save, to: :record, private: true
    #   end
    #
    # @example Attribute settings
    #   class Task
    #     cmdx_attr_setting :default_options, default: -> { {} }
    #     cmdx_attr_setting :configuration, default: {}
    #   end
    #
    # @see Task Tasks that use module extensions for delegation
    # @see Parameter Parameters that use attribute settings
    module ModuleExtensions

      # Create delegator methods that forward calls to another object.
      #
      # This method generates instance methods that delegate to methods on
      # another object. It supports method visibility controls and optional
      # missing method handling.
      #
      # @param methods [Array<Symbol>] method names to delegate
      # @param options [Hash] delegation options
      # @option options [Symbol] :to target object method name (required)
      # @option options [Boolean] :allow_missing whether to allow missing methods
      # @option options [Boolean] :private make delegated methods private
      # @option options [Boolean] :protected make delegated methods protected
      # @return [void]
      #
      # @example Basic delegation
      #   class User
      #     cmdx_attr_delegator :first_name, :last_name, to: :profile
      #     # Creates: def first_name; profile.first_name; end
      #   end
      #
      # @example Private delegation
      #   class Task
      #     cmdx_attr_delegator :validate, to: :validator, private: true
      #   end
      #
      # @example Class delegation
      #   class Task
      #     cmdx_attr_delegator :configuration, to: :class
      #   end
      #
      # @example With missing method handling
      #   class Task
      #     cmdx_attr_delegator :optional_method, to: :service, allow_missing: true
      #   end
      #
      # @raise [NoMethodError] if target object doesn't respond to method and allow_missing is false
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

      # Create class-level attribute accessor with lazy evaluation and inheritance.
      #
      # This method generates a class method that provides lazy-loaded attribute
      # access with inheritance support. Values are cached and can be initialized
      # with default values or procs.
      #
      # @param method [Symbol] name of the attribute method
      # @param options [Hash] attribute options
      # @option options [Object, Proc] :default default value or proc to generate value
      # @return [void]
      #
      # @example Simple attribute setting
      #   class Task
      #     cmdx_attr_setting :timeout, default: 30
      #   end
      #   # Task.timeout => 30
      #
      # @example Dynamic default with proc
      #   class Task
      #     cmdx_attr_setting :timestamp, default: -> { Time.now }
      #   end
      #   # Task.timestamp => current time (evaluated lazily)
      #
      # @example Inherited settings
      #   class BaseTask
      #     cmdx_attr_setting :options, default: {retry: 3}
      #   end
      #
      #   class ProcessTask < BaseTask
      #   end
      #   # ProcessTask.options => {retry: 3} (inherited from BaseTask)
      #
      # @example Hash settings (automatically duplicated)
      #   class Task
      #     cmdx_attr_setting :config, default: {}
      #   end
      #   # Each class gets its own copy of the hash
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

# Extend all modules with CMDx utility methods
Module.include(CMDx::CoreExt::ModuleExtensions)
