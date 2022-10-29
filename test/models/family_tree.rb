# frozen_string_literal: true

class FamilyTree < SecondaryActiveRecord::Base
  belongs_to :member, class_name: "User", foreign_key: "member_id"
  belongs_to :family
end
