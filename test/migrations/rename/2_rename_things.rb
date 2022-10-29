# frozen_string_literal: true

class RenameThings < SecondaryActiveRecord::Migration::Current
  def self.up
    rename_table "things", "awesome_things"
  end

  def self.down
    rename_table "awesome_things", "things"
  end
end
