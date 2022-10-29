# frozen_string_literal: true

class Entrant < SecondaryActiveRecord::Base
  belongs_to :course
end
