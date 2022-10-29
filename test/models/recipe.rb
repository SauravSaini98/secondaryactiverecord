# frozen_string_literal: true

class Recipe < SecondaryActiveRecord::Base
  belongs_to :chef
end
