# frozen_string_literal: true

class Liquid < SecondaryActiveRecord::Base
  self.table_name = :liquid
  has_many :molecules, -> { distinct }
end
