# frozen_string_literal: true

module SecondaryActiveRecord
  module Type
    class DecimalWithoutScale < ActiveModel::Type::BigInteger # :nodoc:
      def type
        :decimal
      end

      def type_cast_for_schema(value)
        value.to_s.inspect
      end
    end
  end
end
