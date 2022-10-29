# frozen_string_literal: true

class Invoice < SecondaryActiveRecord::Base
  has_many :line_items, autosave: true
  before_save { |record| record.balance = record.line_items.map(&:amount).sum }
end
