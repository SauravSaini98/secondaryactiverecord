# frozen_string_literal: true

SecondaryActiveRecord::Base.connection.begin_transaction(joinable: false)

at_exit do
  SecondaryActiveRecord::Base.connection.rollback_transaction
end
