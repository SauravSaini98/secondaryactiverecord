# frozen_string_literal: true

class Country < SecondaryActiveRecord::Base
  self.primary_key = :country_id

  has_and_belongs_to_many :treaties
end
