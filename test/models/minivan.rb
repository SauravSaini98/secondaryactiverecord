# frozen_string_literal: true

class Minivan < SecondaryActiveRecord::Base
  self.primary_key = :minivan_id

  belongs_to :speedometer
  has_one :dashboard, through: :speedometer

  attr_readonly :color
end
