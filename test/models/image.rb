# frozen_string_literal: true

class Image < SecondaryActiveRecord::Base
  belongs_to :imageable, foreign_key: :imageable_identifier, foreign_type: :imageable_class
end
