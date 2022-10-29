# frozen_string_literal: true

require "cases/helper"

class ActiveRecordSchemaTest < SecondaryActiveRecord::TestCase
  self.use_transactional_tests = false

  setup do
    @original_verbose = SecondaryActiveRecord::Migration.verbose
    SecondaryActiveRecord::Migration.verbose = false
    @connection = SecondaryActiveRecord::Base.connection
    SecondaryActiveRecord::SchemaMigration.drop_table
  end

  teardown do
    @connection.drop_table :fruits rescue nil
    @connection.drop_table :nep_fruits rescue nil
    @connection.drop_table :nep_schema_migrations rescue nil
    @connection.drop_table :has_timestamps rescue nil
    @connection.drop_table :multiple_indexes rescue nil
    SecondaryActiveRecord::SchemaMigration.delete_all rescue nil
    SecondaryActiveRecord::Migration.verbose = @original_verbose
  end

  def test_has_primary_key
    old_primary_key_prefix_type = SecondaryActiveRecord::Base.primary_key_prefix_type
    SecondaryActiveRecord::Base.primary_key_prefix_type = :table_name_with_underscore
    assert_equal "version", SecondaryActiveRecord::SchemaMigration.primary_key

    SecondaryActiveRecord::SchemaMigration.create_table
    assert_difference "SecondaryActiveRecord::SchemaMigration.count", 1 do
      SecondaryActiveRecord::SchemaMigration.create version: 12
    end
  ensure
    SecondaryActiveRecord::SchemaMigration.drop_table
    SecondaryActiveRecord::Base.primary_key_prefix_type = old_primary_key_prefix_type
  end

  def test_schema_define
    SecondaryActiveRecord::Schema.define(version: 7) do
      create_table :fruits do |t|
        t.column :color, :string
        t.column :fruit_size, :string  # NOTE: "size" is reserved in Oracle
        t.column :texture, :string
        t.column :flavor, :string
      end
    end

    assert_nothing_raised { @connection.select_all "SELECT * FROM fruits" }
    assert_nothing_raised { @connection.select_all "SELECT * FROM schema_migrations" }
    assert_equal 7, @connection.migration_context.current_version
  end

  def test_schema_define_w_table_name_prefix
    table_name = SecondaryActiveRecord::SchemaMigration.table_name
    old_table_name_prefix = SecondaryActiveRecord::Base.table_name_prefix
    SecondaryActiveRecord::Base.table_name_prefix = "nep_"
    SecondaryActiveRecord::SchemaMigration.table_name = "nep_#{table_name}"
    SecondaryActiveRecord::Schema.define(version: 7) do
      create_table :fruits do |t|
        t.column :color, :string
        t.column :fruit_size, :string  # NOTE: "size" is reserved in Oracle
        t.column :texture, :string
        t.column :flavor, :string
      end
    end
    assert_equal 7, @connection.migration_context.current_version
  ensure
    SecondaryActiveRecord::Base.table_name_prefix = old_table_name_prefix
    SecondaryActiveRecord::SchemaMigration.table_name = table_name
  end

  def test_schema_raises_an_error_for_invalid_column_type
    assert_raise NoMethodError do
      SecondaryActiveRecord::Schema.define(version: 8) do
        create_table :vegetables do |t|
          t.unknown :color
        end
      end
    end
  end

  def test_schema_subclass
    Class.new(SecondaryActiveRecord::Schema).define(version: 9) do
      create_table :fruits
    end
    assert_nothing_raised { @connection.select_all "SELECT * FROM fruits" }
  end

  def test_normalize_version
    assert_equal "118", SecondaryActiveRecord::SchemaMigration.normalize_migration_number("0000118")
    assert_equal "002", SecondaryActiveRecord::SchemaMigration.normalize_migration_number("2")
    assert_equal "017", SecondaryActiveRecord::SchemaMigration.normalize_migration_number("0017")
    assert_equal "20131219224947", SecondaryActiveRecord::SchemaMigration.normalize_migration_number("20131219224947")
  end

  def test_schema_load_with_multiple_indexes_for_column_of_different_names
    SecondaryActiveRecord::Schema.define do
      create_table :multiple_indexes do |t|
        t.string "foo"
        t.index ["foo"], name: "multiple_indexes_foo_1"
        t.index ["foo"], name: "multiple_indexes_foo_2"
      end
    end

    indexes = @connection.indexes("multiple_indexes")

    assert_equal 2, indexes.length
    assert_equal ["multiple_indexes_foo_1", "multiple_indexes_foo_2"], indexes.collect(&:name).sort
  end

  def test_timestamps_without_null_set_null_to_false_on_create_table
    SecondaryActiveRecord::Schema.define do
      create_table :has_timestamps do |t|
        t.timestamps
      end
    end

    assert !@connection.columns(:has_timestamps).find { |c| c.name == "created_at" }.null
    assert !@connection.columns(:has_timestamps).find { |c| c.name == "updated_at" }.null
  end

  def test_timestamps_without_null_set_null_to_false_on_change_table
    SecondaryActiveRecord::Schema.define do
      create_table :has_timestamps

      change_table :has_timestamps do |t|
        t.timestamps default: Time.now
      end
    end

    assert !@connection.columns(:has_timestamps).find { |c| c.name == "created_at" }.null
    assert !@connection.columns(:has_timestamps).find { |c| c.name == "updated_at" }.null
  end

  def test_timestamps_without_null_set_null_to_false_on_add_timestamps
    SecondaryActiveRecord::Schema.define do
      create_table :has_timestamps
      add_timestamps :has_timestamps, default: Time.now
    end

    assert !@connection.columns(:has_timestamps).find { |c| c.name == "created_at" }.null
    assert !@connection.columns(:has_timestamps).find { |c| c.name == "updated_at" }.null
  end
end
