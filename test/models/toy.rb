# frozen_string_literal: true

class Toy < SecondaryActiveRecord::Base
  self.primary_key = :toy_id
  belongs_to :pet

  scope :with_pet, -> { joins(:pet) }
end
