# frozen_string_literal: true

class PriceEstimate < SecondaryActiveRecord::Base
  belongs_to :estimate_of, polymorphic: true
  belongs_to :thing, polymorphic: true
end
