# frozen_string_literal: true

require "cases/helper"

class TestRecord < SecondaryActiveRecord::Base
end

class TestDisconnectedAdapter < SecondaryActiveRecord::TestCase
  self.use_transactional_tests = false

  def setup
    @connection = SecondaryActiveRecord::Base.connection
  end

  teardown do
    return if in_memory_db?
    spec = SecondaryActiveRecord::Base.connection_config
    SecondaryActiveRecord::Base.establish_connection(spec)
  end

  unless in_memory_db?
    test "can't execute statements while disconnected" do
      @connection.execute "SELECT count(*) from products"
      @connection.disconnect!
      assert_raises(SecondaryActiveRecord::StatementInvalid) do
        silence_warnings do
          @connection.execute "SELECT count(*) from products"
        end
      end
    end
  end
end
