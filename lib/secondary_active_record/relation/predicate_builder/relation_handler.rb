# frozen_string_literal: true

module SecondaryActiveRecord
  class PredicateBuilder
    class RelationHandler # :nodoc:
      def call(attribute, value)
        if value.eager_loading?
          value = value.send(:apply_join_dependency)
        end

        if value.select_values.empty?
          value = value.select(value.arel_attribute(value.klass.primary_key))
        end

        attribute.in(value.arel)
      end
    end
  end
end
