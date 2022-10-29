# frozen_string_literal: true

class Notification < SecondaryActiveRecord::Base
  validates_presence_of :message
end
