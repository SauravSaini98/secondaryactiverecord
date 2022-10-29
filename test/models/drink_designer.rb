# frozen_string_literal: true

class DrinkDesigner < SecondaryActiveRecord::Base
  has_one :chef, as: :employable
end

class MocktailDesigner < DrinkDesigner
end
