# frozen_string_literal: true

require "cases/helper"

module SecondaryActiveRecord
  class Migration
    if current_adapter?(:SQLite3Adapter) && !in_memory_db?
      class PendingMigrationsTest < SecondaryActiveRecord::TestCase
        setup do
          file = SecondaryActiveRecord::Base.connection.raw_connection.filename
          @conn = SecondaryActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:", migrations_paths: MIGRATIONS_ROOT + "/valid"
          source_db = SQLite3::Database.new file
          dest_db = SecondaryActiveRecord::Base.connection.raw_connection
          backup = SQLite3::Backup.new(dest_db, "main", source_db, "main")
          backup.step(-1)
          backup.finish
        end

        teardown do
          @conn.release_connection if @conn
          SecondaryActiveRecord::Base.establish_connection :arunit
        end

        def test_errors_if_pending
          SecondaryActiveRecord::Base.connection.drop_table "schema_migrations", if_exists: true

          assert_raises SecondaryActiveRecord::PendingMigrationError do
            CheckPending.new(Proc.new {}).call({})
          end
        end

        def test_checks_if_supported
          SecondaryActiveRecord::SchemaMigration.create_table
          migrator = Base.connection.migration_context
          capture(:stdout) { migrator.migrate }

          assert_nil CheckPending.new(Proc.new {}).call({})
        end
      end
    end
  end
end
