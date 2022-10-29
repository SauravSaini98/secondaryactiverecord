# frozen_string_literal: true

class Task < SecondaryActiveRecord::Base
  def updated_at
    ending
  end
end
