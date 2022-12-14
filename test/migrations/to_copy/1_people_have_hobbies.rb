# frozen_string_literal: true

class PeopleHaveHobbies < SecondaryActiveRecord::Migration::Current
  def self.up
    add_column "people", "hobbies", :text
  end

  def self.down
    remove_column "people", "hobbies"
  end
end
