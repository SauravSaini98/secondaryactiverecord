# frozen_string_literal: true

module ConnectionHelper
  def run_without_connection
    original_connection = SecondaryActiveRecord::Base.remove_connection
    yield original_connection
  ensure
    SecondaryActiveRecord::Base.establish_connection(original_connection)
  end

  # Used to drop all cache query plans in tests.
  def reset_connection
    original_connection = SecondaryActiveRecord::Base.remove_connection
    SecondaryActiveRecord::Base.establish_connection(original_connection)
  end
end
