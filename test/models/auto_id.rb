# frozen_string_literal: true

class AutoId < SecondaryActiveRecord::Base
  self.table_name = "auto_id_tests"
  self.primary_key = "auto_id"
end
