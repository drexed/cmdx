# frozen_string_literal: true

module CMDx
  # Coerces and validates inputs using frozen {AttributeSpec}s and {ExtensionSet}.
  class AttributePipeline

    # @param session [Session]
    # @return [void]
    def self.apply_all(session)
      definition = session.handler.class.definition
      extensions = definition.extensions
      raw = session.raw_input

      definition.attribute_specs.each do |spec|
        apply_spec(session, spec, raw, extensions)
      end

      filter_strong_context!(session) if definition.strong_context
    end

    # @param session [Session]
    # @param spec [AttributeSpec]
    # @param raw [Hash]
    # @param extensions [ExtensionSet]
    # @return [void]
    def self.apply_spec(session, spec, raw, extensions)
      key = spec.name
      val = raw[key] || raw[spec.reader_name]

      val = spec.options[:default] if val.nil? && spec.options.key?(:default)

      if spec.required && missing?(val)
        session.errors.add(spec.reader_name, Locale.t("cmdx.validators.presence"))
        return
      end

      return if val.nil? && !spec.required

      coerced = coerce_value(session, spec, val, extensions)
      return if session.errors.for?(spec.reader_name)

      validate_value(session, spec, coerced, extensions)
      return if session.errors.for?(spec.reader_name)

      session.context[key] = coerced
      session.handler.write_attribute!(spec.reader_name, coerced)
    end

    # @param val [Object]
    # @return [Boolean]
    def self.missing?(val)
      val.nil? || (val.is_a?(String) && !/\S/.match?(val))
    end

    # @param session [Session]
    # @param spec [AttributeSpec]
    # @param val [Object]
    # @param extensions [ExtensionSet]
    # @return [Object, nil]
    def self.coerce_value(session, spec, val, extensions)
      type_keys = spec.type_keys
      return val if type_keys.empty?

      key = type_keys.first
      fn = extensions.coercions[key]
      unless fn
        session.errors.add(spec.reader_name, Locale.t("cmdx.coercions.unknown", type: key))
        return nil
      end

      fn.call(val, context: session, attribute: spec, **spec.options)
    rescue CoercionError => e
      session.errors.add(spec.reader_name, e.message)
      nil
    end

    # @param session [Session]
    # @param spec [AttributeSpec]
    # @param val [Object]
    # @param extensions [ExtensionSet]
    # @return [void]
    def self.validate_value(session, spec, val, extensions)
      spec.validators.each do |v|
        name = v[:name].to_sym
        opts = (v[:options] || {}).dup
        next unless validator_applies?(session.handler, session, val, opts)

        fn = extensions.validators[name]
        unless fn
          session.errors.add(spec.reader_name, "unknown validator #{name}")
          next
        end

        fn.call(val, context: session, attribute: spec, **opts)
      rescue ValidationError => e
        session.errors.add(spec.reader_name, e.message)
      end
    end

    # @param handler [Task]
    # @param session [Session]
    # @param value [Object]
    # @param options [Hash]
    # @return [Boolean]
    def self.validator_applies?(handler, _session, value, options)
      return true unless options.is_a?(Hash)

      return !options[:allow_nil] if options.key?(:allow_nil) && value.nil?

      cond_opts = options.slice(:if, :unless)
      return true if cond_opts.empty?

      Utils::Condition.evaluate(handler, cond_opts, value)
    end

    # @param session [Session]
    # @return [void]
    def self.filter_strong_context!(session)
      definition = session.handler.class.definition
      allowed = definition.attribute_specs.flat_map { |s| [s.name, s.reader_name] }.uniq
      session.context.to_h.delete_if { |k, _| !allowed.include?(k) }
    end

  end
end
