# frozen_string_literal: true

class Molecule < SecondaryActiveRecord::Base
  belongs_to :liquid
  has_many :electrons

  accepts_nested_attributes_for :electrons
end
