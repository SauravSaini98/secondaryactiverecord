# frozen_string_literal: true

module SecondaryActiveRecord
  # = Secondary Active Record Query Cache
  class QueryCache
    module ClassMethods
      # Enable the query cache within the block if Secondary Active Record is configured.
      # If it's not, it will execute the given block.
      def cache(&block)
        if connected? || !configurations.empty?
          connection.cache(&block)
        else
          yield
        end
      end

      # Disable the query cache within the block if Secondary Active Record is configured.
      # If it's not, it will execute the given block.
      def uncached(&block)
        if connected? || !configurations.empty?
          connection.uncached(&block)
        else
          yield
        end
      end
    end

    def self.run
      SecondaryActiveRecord::Base.connection_handler.connection_pool_list.
        reject { |p| p.query_cache_enabled }.each { |p| p.enable_query_cache! }
    end

    def self.complete(pools)
      pools.each { |pool| pool.disable_query_cache! }

      SecondaryActiveRecord::Base.connection_handler.connection_pool_list.each do |pool|
        pool.release_connection if pool.active_connection? && !pool.connection.transaction_open?
      end
    end

    def self.install_executor_hooks(executor = ActiveSupport::Executor)
      executor.register_hook(self)
    end
  end
end
