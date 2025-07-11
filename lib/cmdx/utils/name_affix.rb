# frozen_string_literal: true

module CMDx
  module Utils
    # Utility module for generating method names with configurable prefixes and suffixes.
    #
    # This module provides functionality to dynamically construct method names
    # by applying prefixes and suffixes to a base method name, with support
    # for custom naming through options.
    module NameAffix

      # Proc that handles affix logic - returns block result if value is true, otherwise returns value as-is.
      AFFIX = proc do |o, &block|
        o == true ? block.call : o
      end.freeze

      module_function

      # Generates a method name with optional prefix and suffix based on source and options.
      #
      # @param method_name [String, Symbol] the base method name to be affixed
      # @param source [String, Symbol] the source identifier used for generating default prefixes/suffixes
      # @param options [Hash] configuration options for name generation
      # @option options [String, Symbol, true] :prefix custom prefix or true for default "#{source}_"
      # @option options [String, Symbol, true] :suffix custom suffix or true for default "_#{source}"
      # @option options [String, Symbol] :as override the entire generated name
      #
      # @return [Symbol] the generated method name as a symbol
      #
      # @example Using default prefix and suffix
      #   NameAffix.call("process", "user", prefix: true, suffix: true) #=> :user_process_user
      #
      # @example Using custom prefix
      #   NameAffix.call("process", "user", prefix: "handle_") #=> :handle_process
      #
      # @example Using custom suffix
      #   NameAffix.call("process", "user", suffix: "_data") #=> :process_data
      #
      # @example Overriding with custom name
      #   NameAffix.call("process", "user", as: "custom_method") #=> :custom_method
      def call(method_name, source, options = {})
        options[:as] || begin
          prefix = AFFIX.call(options[:prefix]) { "#{source}_" }
          suffix = AFFIX.call(options[:suffix]) { "_#{source}" }

          "#{prefix}#{method_name}#{suffix}".strip.to_sym
        end
      end

    end
  end
end
