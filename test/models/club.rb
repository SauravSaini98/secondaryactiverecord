# frozen_string_literal: true

class Club < SecondaryActiveRecord::Base
  has_one :membership
  has_many :memberships, inverse_of: false
  has_many :members, through: :memberships
  has_one :sponsor
  has_one :sponsored_member, through: :sponsor, source: :sponsorable, source_type: "Member"
  belongs_to :category

  has_many :favourites, -> { where(memberships: { favourite: true }) }, through: :memberships, source: :member

  scope :general, -> { left_joins(:category).where(categories: { name: "General" }) }

  private

    def private_method
      "I'm sorry sir, this is a *private* club, not a *pirate* club"
    end
end

class SuperClub < SecondaryActiveRecord::Base
  self.table_name = "clubs"

  has_many :memberships, class_name: "SuperMembership", foreign_key: "club_id"
  has_many :members, through: :memberships
end
