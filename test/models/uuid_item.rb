# frozen_string_literal: true

class UuidItem < SecondaryActiveRecord::Base
end

class UuidValidatingItem < UuidItem
  validates_uniqueness_of :uuid
end
