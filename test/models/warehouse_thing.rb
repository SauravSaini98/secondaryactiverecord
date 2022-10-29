# frozen_string_literal: true

class WarehouseThing < SecondaryActiveRecord::Base
  self.table_name = "warehouse-things"

  validates_uniqueness_of :value
end
