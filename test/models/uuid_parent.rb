# frozen_string_literal: true

class UuidParent < SecondaryActiveRecord::Base
  has_many :uuid_children
end
