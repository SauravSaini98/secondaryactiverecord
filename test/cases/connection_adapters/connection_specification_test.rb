# frozen_string_literal: true

require "cases/helper"

module SecondaryActiveRecord
  module ConnectionAdapters
    class ConnectionSpecificationTest < SecondaryActiveRecord::TestCase
      def test_dup_deep_copy_config
        spec = ConnectionSpecification.new("primary", { a: :b }, "bar")
        assert_not_equal(spec.config.object_id, spec.dup.config.object_id)
      end
    end
  end
end
