# frozen_string_literal: true

module CMDx
  module Utils
    # Utility for generating method names with prefixes and suffixes.
    #
    # NameAffix provides flexible method name generation for dynamic method
    # creation, delegation, and metaprogramming scenarios. Supports custom
    # prefixes, suffixes, and complete name overrides for method naming
    # conventions in CMDx's parameter and delegation systems.
    #
    # @example Basic prefix and suffix usage
    #   Utils::NameAffix.call(:name, "user", prefix: true, suffix: true)
    #   # => :user_name_user
    #
    # @example Custom prefix
    #   Utils::NameAffix.call(:email, "admin", prefix: "get_")
    #   # => :get_email
    #
    # @example Custom suffix
    #   Utils::NameAffix.call(:count, "items", suffix: "_total")
    #   # => :count_total
    #
    # @example Complete name override
    #   Utils::NameAffix.call(:original, "source", as: :custom_method)
    #   # => :custom_method
    #
    # @example Parameter delegation usage
    #   class MyTask < CMDx::Task
    #     required :user_id
    #
    #     # Internally uses NameAffix for method generation
    #     # Creates methods like user_id, user_id?, etc.
    #   end
    #
    # @see CMDx::Parameter Uses this for parameter method name generation
    # @see CMDx::CoreExt::Module Uses this for delegation method naming
    module NameAffix

      # Proc for handling affix logic with boolean or custom values
      # @return [Proc] processor for affix options that handles true/false and custom strings
      AFFIX = proc do |o, &block|
        o == true ? block.call : o
      end.freeze

      module_function

      # Generates a method name with optional prefix and suffix.
      #
      # Creates a method name by combining the base method name with optional
      # prefixes and suffixes. Supports boolean flags for default affixes or
      # custom string values for specific naming patterns.
      #
      # @param method_name [Symbol, String] Base method name to transform
      # @param source [String] Source identifier used for default prefix/suffix generation
      # @param options [Hash] Configuration options for name generation
      # @option options [Boolean, String] :prefix (false) Add prefix - true for "#{source}_", string for custom
      # @option options [Boolean, String] :suffix (false) Add suffix - true for "_#{source}", string for custom
      # @option options [Symbol] :as Override the entire generated name
      #
      # @return [Symbol] Generated method name with applied affixes
      #
      # @example Default prefix generation
      #   NameAffix.call(:method, "user", prefix: true)
      #   # => :user_method
      #
      # @example Custom prefix
      #   NameAffix.call(:method, "user", prefix: "get_")
      #   # => :get_method
      #
      # @example Default suffix generation
      #   NameAffix.call(:method, "user", suffix: true)
      #   # => :method_user
      #
      # @example Custom suffix
      #   NameAffix.call(:method, "user", suffix: "_count")
      #   # => :method_count
      #
      # @example Combined prefix and suffix
      #   NameAffix.call(:name, "user", prefix: "get_", suffix: "_value")
      #   # => :get_name_value
      #
      # @example Complete name override (ignores prefix/suffix)
      #   NameAffix.call(:original, "user", prefix: true, as: :custom)
      #   # => :custom
      #
      # @example Parameter method generation
      #   # CMDx internally uses this for parameter methods:
      #   NameAffix.call(:email, "user", suffix: "?")  # => :email?
      #   NameAffix.call(:process, "order", prefix: "can_")  # => :can_process
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
