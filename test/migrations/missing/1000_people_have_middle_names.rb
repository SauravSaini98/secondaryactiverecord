# frozen_string_literal: true

class PeopleHaveMiddleNames < SecondaryActiveRecord::Migration::Current
  def self.up
    add_column "people", "middle_name", :string
  end

  def self.down
    remove_column "people", "middle_name"
  end
end
