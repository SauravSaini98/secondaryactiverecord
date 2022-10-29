# frozen_string_literal: true

class MemberType < SecondaryActiveRecord::Base
  has_many :members
end
