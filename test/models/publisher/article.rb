# frozen_string_literal: true

class Publisher::Article < SecondaryActiveRecord::Base
  has_and_belongs_to_many :magazines
  has_and_belongs_to_many :tags
end
