# frozen_string_literal: true

class Tree < SecondaryActiveRecord::Base
  has_many :nodes, dependent: :destroy
end
