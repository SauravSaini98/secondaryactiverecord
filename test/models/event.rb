# frozen_string_literal: true

class Event < SecondaryActiveRecord::Base
  validates_uniqueness_of :title
end
