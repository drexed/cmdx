# frozen_string_literal: true

module CMDx

  class EventRegistry

    attr_reader :subscribers

    def initialize(subscribers = {})
      @subscribers = subscribers
    end

    def dup
      self.class.new(@subscribers.dup)
    end

    def subscribe(event_pattern, callable = nil, &block)
      callable ||= block
      raise ArgumentError, "must provide a callable or block" unless callable

      pattern = normalize_pattern(event_pattern)
      @subscribers[pattern] ||= []
      @subscribers[pattern] << callable
      self
    end

    def all(callable = nil, &)
      subscribe("*", callable, &)
    end

    def publish(event_name, event_data = {})
      matching_patterns(event_name).each do |pattern|
        @subscribers[pattern]&.each do |callable|
          invoke_subscriber(callable, event_name, event_data)
        end
      end
    end

    def listening?(event_name)
      matching_patterns(event_name).any? { |pattern| @subscribers[pattern]&.any? }
    end

    def clear
      @subscribers.clear
      self
    end

    private

    def normalize_pattern(pattern)
      return "*" if pattern.nil? || pattern == "*"

      pattern.to_s
    end

    def matching_patterns(event_name)
      event_name = event_name.to_s
      @subscribers.keys.select do |pattern|
        pattern == "*" ||
          pattern == event_name ||
          (pattern.end_with?("*") && event_name.start_with?(pattern[0..-2]))
      end
    end

    def invoke_subscriber(callable, event_name, event_data)
      event = Event.new(event_name, event_data)

      case callable
      when Symbol, String
        # Method name - would need task context to call
        raise ArgumentError, "Symbol/String callables not supported in EventRegistry"
      when Proc, Method
        callable.call(event)
      else
        # Object that responds to #call
        raise ArgumentError, "Callable must respond to #call" unless callable.respond_to?(:call)

        if callable.method(:call).arity == 1
          callable.call(event)
        else
          callable.call(event_name, event_data)
        end

      end
    rescue StandardError => e
      # Log error but don't break other subscribers
      CMDx.configuration.logger.error("Event subscriber error: #{e.class}: #{e.message}")
      CMDx.configuration.logger.debug(e.backtrace.join("\n")) if CMDx.configuration.logger.debug?
    end

  end

  extend self

  # Convenience methods for global event system
  def subscribe(event_pattern, callable = nil, &)
    configuration.events.subscribe(event_pattern, callable, &)
  end

  def all(callable = nil, &)
    configuration.events.all(callable, &)
  end

  def publish(event_name, event_data = {})
    configuration.events.publish(event_name, event_data)
  end

  def listening?(event_name)
    configuration.events.listening?(event_name)
  end

end
