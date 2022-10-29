# frozen_string_literal: true

class Matey < SecondaryActiveRecord::Base
  belongs_to :pirate
  belongs_to :target, class_name: "Pirate"
end
