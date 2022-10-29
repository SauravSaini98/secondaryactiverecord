# frozen_string_literal: true

class Speedometer < SecondaryActiveRecord::Base
  self.primary_key = :speedometer_id
  belongs_to :dashboard

  has_many :minivans
end
