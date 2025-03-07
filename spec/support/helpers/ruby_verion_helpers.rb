module RubyVersionHelpers

  module_function

  def min?(version)
    Gem::Version.new(RUBY_VERSION) >= Gem::Version.new(version.to_s)
  end

  def max?(version)
    Gem::Version.new(RUBY_VERSION) <= Gem::Version.new(version.to_s)
  end

end
