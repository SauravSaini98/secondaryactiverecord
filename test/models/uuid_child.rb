# frozen_string_literal: true

class UuidChild < SecondaryActiveRecord::Base
  belongs_to :uuid_parent
end
