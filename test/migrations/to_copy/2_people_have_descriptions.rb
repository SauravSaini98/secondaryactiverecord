# frozen_string_literal: true

class PeopleHaveDescriptions < SecondaryActiveRecord::Migration::Current
  def self.up
    add_column "people", "description", :text
  end

  def self.down
    remove_column "people", "description"
  end
end
