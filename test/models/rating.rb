# frozen_string_literal: true

class Rating < SecondaryActiveRecord::Base
  belongs_to :comment
  has_many :taggings, as: :taggable
end
