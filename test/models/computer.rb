# frozen_string_literal: true

class Computer < SecondaryActiveRecord::Base
  belongs_to :developer, foreign_key: "developer"
end
