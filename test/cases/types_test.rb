# frozen_string_literal: true

require "cases/helper"

module SecondaryActiveRecord
  module ConnectionAdapters
    class TypesTest < SecondaryActiveRecord::TestCase
      def test_attributes_which_are_invalid_for_database_can_still_be_reassigned
        type_which_cannot_go_to_the_database = Type::Value.new
        def type_which_cannot_go_to_the_database.serialize(*)
          raise
        end
        klass = Class.new(SecondaryActiveRecord::Base) do
          self.table_name = "posts"
          attribute :foo, type_which_cannot_go_to_the_database
        end
        model = klass.new

        model.foo = "foo"
        model.foo = "bar"

        assert_equal "bar", model.foo
      end
    end
  end
end
