# frozen_string_literal: true

class Admin::ClassNameThatDoesNotFollowCONVENTIONS1 < SecondaryActiveRecord::Base
  self.table_name = :randomly_named_table2
end

class Admin::ClassNameThatDoesNotFollowCONVENTIONS2 < SecondaryActiveRecord::Base
  self.table_name = :randomly_named_table3
end
