# frozen_string_literal: true

class Department < SecondaryActiveRecord::Base
  has_many :chefs
  belongs_to :hotel
end
