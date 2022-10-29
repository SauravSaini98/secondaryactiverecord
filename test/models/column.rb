# frozen_string_literal: true

class Column < SecondaryActiveRecord::Base
  belongs_to :record
end
