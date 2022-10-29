# frozen_string_literal: true

class Frog < SecondaryActiveRecord::Base
  after_save do
    with_lock do
    end
  end
end
