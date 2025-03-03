# frozen_string_literal: true

module CMDx
  module CoreExt
    module HashExtensions

      def __cmdx_fetch(key)
        case key
        when Symbol then fetch(key) { self[key.to_s] }
        when String then fetch(key) { self[key.to_sym] }
        else self[key]
        end
      end

      def __cmdx_key?(key)
        key?(key) || key?(
          case key
          when Symbol then key.to_s
          when String then key.to_sym
          end
        )
      rescue NoMethodError
        false
      end

      def __cmdx_respond_to?(key, include_private = false)
        respond_to?(key.to_sym, include_private) || __cmdx_key?(key)
      rescue NoMethodError
        __cmdx_key?(key)
      end

    end
  end
end

Hash.include(CMDx::CoreExt::HashExtensions)
