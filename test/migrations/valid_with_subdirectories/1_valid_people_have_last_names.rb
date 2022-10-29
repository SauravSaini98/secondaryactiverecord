# frozen_string_literal: true

class ValidPeopleHaveLastNames < SecondaryActiveRecord::Migration::Current
  def self.up
    add_column "people", "last_name", :string
  end

  def self.down
    remove_column "people", "last_name"
  end
end
