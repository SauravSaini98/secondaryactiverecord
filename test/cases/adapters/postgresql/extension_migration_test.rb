# frozen_string_literal: true

require "cases/helper"

class PostgresqlExtensionMigrationTest < SecondaryActiveRecord::PostgreSQLTestCase
  self.use_transactional_tests = false

  class EnableHstore < SecondaryActiveRecord::Migration::Current
    def change
      enable_extension "hstore"
    end
  end

  class DisableHstore < SecondaryActiveRecord::Migration::Current
    def change
      disable_extension "hstore"
    end
  end

  def setup
    super

    @connection = SecondaryActiveRecord::Base.connection

    @old_schema_migration_table_name = SecondaryActiveRecord::SchemaMigration.table_name
    @old_table_name_prefix = SecondaryActiveRecord::Base.table_name_prefix
    @old_table_name_suffix = SecondaryActiveRecord::Base.table_name_suffix

    SecondaryActiveRecord::Base.table_name_prefix = "p_"
    SecondaryActiveRecord::Base.table_name_suffix = "_s"
    SecondaryActiveRecord::SchemaMigration.delete_all rescue nil
    SecondaryActiveRecord::SchemaMigration.table_name = "p_schema_migrations_s"
    SecondaryActiveRecord::Migration.verbose = false
  end

  def teardown
    SecondaryActiveRecord::Base.table_name_prefix = @old_table_name_prefix
    SecondaryActiveRecord::Base.table_name_suffix = @old_table_name_suffix
    SecondaryActiveRecord::SchemaMigration.delete_all rescue nil
    SecondaryActiveRecord::Migration.verbose = true
    SecondaryActiveRecord::SchemaMigration.table_name = @old_schema_migration_table_name

    super
  end

  def test_enable_extension_migration_ignores_prefix_and_suffix
    @connection.disable_extension("hstore")

    migrations = [EnableHstore.new(nil, 1)]
    SecondaryActiveRecord::Migrator.new(:up, migrations).migrate
    assert @connection.extension_enabled?("hstore"), "extension hstore should be enabled"
  end

  def test_disable_extension_migration_ignores_prefix_and_suffix
    @connection.enable_extension("hstore")

    migrations = [DisableHstore.new(nil, 1)]
    SecondaryActiveRecord::Migrator.new(:up, migrations).migrate
    assert_not @connection.extension_enabled?("hstore"), "extension hstore should not be enabled"
  end
end
