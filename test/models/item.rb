# frozen_string_literal: true

class AbstractItem < SecondaryActiveRecord::Base
  self.abstract_class = true
  has_one :tagging, as: :taggable
end

class Item < AbstractItem
end
