# frozen_string_literal: true

require "cases/helper"

module SecondaryActiveRecord
  module Type
    class UnsignedIntegerTest < SecondaryActiveRecord::TestCase
      test "unsigned int max value is in range" do
        assert_equal(4294967295, UnsignedInteger.new.serialize(4294967295))
      end

      test "minus value is out of range" do
        assert_raises(ActiveModel::RangeError) do
          UnsignedInteger.new.serialize(-1)
        end
      end
    end
  end
end
