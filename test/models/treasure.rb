# frozen_string_literal: true

class Treasure < SecondaryActiveRecord::Base
  has_and_belongs_to_many :parrots
  belongs_to :looter, polymorphic: true
  # No counter_cache option given
  belongs_to :ship

  has_many :price_estimates, as: :estimate_of
  has_and_belongs_to_many :rich_people, join_table: "peoples_treasures", validate: false

  accepts_nested_attributes_for :looter
end

class HiddenTreasure < Treasure
end
