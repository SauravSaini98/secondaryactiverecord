# frozen_string_literal: true

class CakeDesigner < SecondaryActiveRecord::Base
  has_one :chef, as: :employable
end
