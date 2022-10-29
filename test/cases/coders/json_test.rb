# frozen_string_literal: true

require "cases/helper"

module SecondaryActiveRecord
  module Coders
    class JSONTest < SecondaryActiveRecord::TestCase
      def test_returns_nil_if_empty_string_given
        assert_nil JSON.load("")
      end

      def test_returns_nil_if_nil_given
        assert_nil JSON.load(nil)
      end
    end
  end
end
