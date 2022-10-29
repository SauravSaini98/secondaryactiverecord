# frozen_string_literal: true

require "active_support/per_thread_registry"

module SecondaryActiveRecord
  # This is a thread locals registry for Secondary Active Record. For example:
  #
  #   SecondaryActiveRecord::RuntimeRegistry.connection_handler
  #
  # returns the connection handler local to the current thread.
  #
  # See the documentation of ActiveSupport::PerThreadRegistry
  # for further details.
  class RuntimeRegistry # :nodoc:
    extend ActiveSupport::PerThreadRegistry

    attr_accessor :connection_handler, :sql_runtime

    [:connection_handler, :sql_runtime].each do |val|
      class_eval %{ def self.#{val}; instance.#{val}; end }, __FILE__, __LINE__
      class_eval %{ def self.#{val}=(x); instance.#{val}=x; end }, __FILE__, __LINE__
    end
  end
end
