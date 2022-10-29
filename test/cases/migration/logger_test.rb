# frozen_string_literal: true

require "cases/helper"

module SecondaryActiveRecord
  class Migration
    class LoggerTest < SecondaryActiveRecord::TestCase
      # MySQL can't roll back ddl changes
      self.use_transactional_tests = false

      Migration = Struct.new(:name, :version) do
        def disable_ddl_transaction; false end
        def migrate(direction)
          # do nothing
        end
      end

      def setup
        super
        SecondaryActiveRecord::SchemaMigration.create_table
        SecondaryActiveRecord::SchemaMigration.delete_all
      end

      teardown do
        SecondaryActiveRecord::SchemaMigration.drop_table
      end

      def test_migration_should_be_run_without_logger
        previous_logger = SecondaryActiveRecord::Base.logger
        SecondaryActiveRecord::Base.logger = nil
        migrations = [Migration.new("a", 1), Migration.new("b", 2), Migration.new("c", 3)]
        SecondaryActiveRecord::Migrator.new(:up, migrations).migrate
      ensure
        SecondaryActiveRecord::Base.logger = previous_logger
      end
    end
  end
end
