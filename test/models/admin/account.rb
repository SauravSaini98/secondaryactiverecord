# frozen_string_literal: true

class Admin::Account < SecondaryActiveRecord::Base
  has_many :users
end
