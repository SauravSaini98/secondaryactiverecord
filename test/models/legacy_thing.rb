# frozen_string_literal: true

class LegacyThing < SecondaryActiveRecord::Base
  self.locking_column = :version
end
