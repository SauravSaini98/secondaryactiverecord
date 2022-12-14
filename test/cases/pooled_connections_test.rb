# frozen_string_literal: true

require "cases/helper"
require "models/project"
require "timeout"

class PooledConnectionsTest < SecondaryActiveRecord::TestCase
  self.use_transactional_tests = false

  def setup
    @per_test_teardown = []
    @connection = SecondaryActiveRecord::Base.remove_connection
  end

  teardown do
    SecondaryActiveRecord::Base.clear_all_connections!
    SecondaryActiveRecord::Base.establish_connection(@connection)
    @per_test_teardown.each(&:call)
  end

  # Will deadlock due to lack of Monitor timeouts in 1.9
  def checkout_checkin_connections(pool_size, threads)
    SecondaryActiveRecord::Base.establish_connection(@connection.merge(pool: pool_size, checkout_timeout: 0.5))
    @connection_count = 0
    @timed_out = 0
    threads.times do
      Thread.new do
        begin
          conn = SecondaryActiveRecord::Base.connection_pool.checkout
          sleep 0.1
          SecondaryActiveRecord::Base.connection_pool.checkin conn
          @connection_count += 1
        rescue SecondaryActiveRecord::ConnectionTimeoutError
          @timed_out += 1
        end
      end.join
    end
  end

  def checkout_checkin_connections_loop(pool_size, loops)
    SecondaryActiveRecord::Base.establish_connection(@connection.merge(pool: pool_size, checkout_timeout: 0.5))
    @connection_count = 0
    @timed_out = 0
    loops.times do
      begin
        conn = SecondaryActiveRecord::Base.connection_pool.checkout
        SecondaryActiveRecord::Base.connection_pool.checkin conn
        @connection_count += 1
        SecondaryActiveRecord::Base.connection.data_sources
      rescue SecondaryActiveRecord::ConnectionTimeoutError
        @timed_out += 1
      end
    end
  end

  def test_pooled_connection_checkin_one
    checkout_checkin_connections 1, 2
    assert_equal 2, @connection_count
    assert_equal 0, @timed_out
    assert_equal 1, SecondaryActiveRecord::Base.connection_pool.connections.size
  end

  def test_pooled_connection_checkin_two
    checkout_checkin_connections_loop 2, 3
    assert_equal 3, @connection_count
    assert_equal 0, @timed_out
    assert_equal 2, SecondaryActiveRecord::Base.connection_pool.connections.size
  end

  def test_pooled_connection_remove
    SecondaryActiveRecord::Base.establish_connection(@connection.merge(pool: 2, checkout_timeout: 0.5))
    old_connection = SecondaryActiveRecord::Base.connection
    extra_connection = SecondaryActiveRecord::Base.connection_pool.checkout
    SecondaryActiveRecord::Base.connection_pool.remove(extra_connection)
    assert_equal SecondaryActiveRecord::Base.connection, old_connection
  end

  private

    def add_record(name)
      SecondaryActiveRecord::Base.connection_pool.with_connection { Project.create! name: name }
    end
end unless in_memory_db?
