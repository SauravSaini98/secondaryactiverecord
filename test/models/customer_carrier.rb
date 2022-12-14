# frozen_string_literal: true

class CustomerCarrier < SecondaryActiveRecord::Base
  cattr_accessor :current_customer

  belongs_to :customer
  belongs_to :carrier

  default_scope -> {
    if current_customer
      where(customer: current_customer)
    else
      all
    end
  }
end
