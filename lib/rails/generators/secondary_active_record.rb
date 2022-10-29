# frozen_string_literal: true

require "rails/generators/named_base"
require "rails/generators/active_model"
require "rails/generators/secondary_active_record/migration"
require "secondary_active_record"

module SecondaryActiveRecord
  module Generators # :nodoc:
    class Base < Rails::Generators::NamedBase # :nodoc:
      include SecondaryActiveRecord::Generators::Migration

      # Set the current directory as base for the inherited generators.
      def self.base_root
        __dir__
      end
    end
  end
end
