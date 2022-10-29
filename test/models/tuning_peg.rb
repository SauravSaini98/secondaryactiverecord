# frozen_string_literal: true

class TuningPeg < SecondaryActiveRecord::Base
  belongs_to :guitar
  validates_numericality_of :pitch
end
