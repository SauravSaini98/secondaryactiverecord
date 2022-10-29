# frozen_string_literal: true

class Zine < SecondaryActiveRecord::Base
  has_many :interests, inverse_of: :zine
end
