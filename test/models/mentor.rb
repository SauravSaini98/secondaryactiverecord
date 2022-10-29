# frozen_string_literal: true

class Mentor < SecondaryActiveRecord::Base
  has_many :developers
end
