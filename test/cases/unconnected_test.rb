# frozen_string_literal: true

require "cases/helper"

class TestRecord < SecondaryActiveRecord::Base
end

class TestUnconnectedAdapter < SecondaryActiveRecord::TestCase
  self.use_transactional_tests = false

  def setup
    @underlying = SecondaryActiveRecord::Base.connection
    @specification = SecondaryActiveRecord::Base.remove_connection
  end

  teardown do
    @underlying = nil
    SecondaryActiveRecord::Base.establish_connection(@specification)
    load_schema if in_memory_db?
  end

  def test_connection_no_longer_established
    assert_raise(SecondaryActiveRecord::ConnectionNotEstablished) do
      TestRecord.find(1)
    end

    assert_raise(SecondaryActiveRecord::ConnectionNotEstablished) do
      TestRecord.new.save
    end
  end

  def test_underlying_adapter_no_longer_active
    assert !@underlying.active?, "Removed adapter should no longer be active"
  end
end
