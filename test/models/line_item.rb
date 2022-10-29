# frozen_string_literal: true

class LineItem < SecondaryActiveRecord::Base
  belongs_to :invoice, touch: true
end
