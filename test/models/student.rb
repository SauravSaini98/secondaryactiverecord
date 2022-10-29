# frozen_string_literal: true

class Student < SecondaryActiveRecord::Base
  has_and_belongs_to_many :lessons
  belongs_to :college
end
