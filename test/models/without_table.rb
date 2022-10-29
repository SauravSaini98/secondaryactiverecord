# frozen_string_literal: true

class WithoutTable < SecondaryActiveRecord::Base
  default_scope -> { where(published: true) }
end
