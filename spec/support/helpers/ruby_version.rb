# frozen_string_literal: true

module RubyVersion

  extend self

  def version
    @version ||= Gem::Version.new(RUBY_VERSION)
  end

  def min?(min)
    version >= Gem::Version.new(min.to_s)
  end

  def max?(max)
    version <= Gem::Version.new(max.to_s)
  end

end
