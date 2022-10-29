# frozen_string_literal: true

require_relative "gem_version"

module SecondaryActiveRecord
  # Returns the version of the currently loaded SecondaryActiveRecord as a <tt>Gem::Version</tt>
  def self.version
    gem_version
  end
end
