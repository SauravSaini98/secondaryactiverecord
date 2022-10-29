# frozen_string_literal: true

class Joke < SecondaryActiveRecord::Base
  self.table_name = "funny_jokes"
end

class GoodJoke < SecondaryActiveRecord::Base
  self.table_name = "funny_jokes"
end
