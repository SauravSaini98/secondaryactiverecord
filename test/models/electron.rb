# frozen_string_literal: true

class Electron < SecondaryActiveRecord::Base
  belongs_to :molecule

  validates_presence_of :name
end
