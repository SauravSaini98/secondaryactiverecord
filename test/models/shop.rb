# frozen_string_literal: true

module Shop
  class Collection < SecondaryActiveRecord::Base
    has_many :products, dependent: :nullify
  end

  class Product < SecondaryActiveRecord::Base
    has_many :variants, dependent: :delete_all
    belongs_to :type

    class Type < SecondaryActiveRecord::Base
      has_many :products
    end
  end

  class Variant < SecondaryActiveRecord::Base
  end
end
