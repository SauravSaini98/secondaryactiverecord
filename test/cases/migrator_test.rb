# frozen_string_literal: true

require "cases/helper"
require "cases/migration/helper"

class MigratorTest < SecondaryActiveRecord::TestCase
  self.use_transactional_tests = false

  # Use this class to sense if migrations have gone
  # up or down.
  class Sensor < SecondaryActiveRecord::Migration::Current
    attr_reader :went_up, :went_down

    def initialize(name = self.class.name, version = nil)
      super
      @went_up = false
      @went_down = false
    end

    def up; @went_up = true; end
    def down; @went_down = true; end
  end

  def setup
    super
    SecondaryActiveRecord::SchemaMigration.create_table
    SecondaryActiveRecord::SchemaMigration.delete_all rescue nil
    @verbose_was = SecondaryActiveRecord::Migration.verbose
    SecondaryActiveRecord::Migration.message_count = 0
    SecondaryActiveRecord::Migration.class_eval do
      undef :puts
      def puts(*)
        SecondaryActiveRecord::Migration.message_count += 1
      end
    end
  end

  teardown do
    SecondaryActiveRecord::SchemaMigration.delete_all rescue nil
    SecondaryActiveRecord::Migration.verbose = @verbose_was
    SecondaryActiveRecord::Migration.class_eval do
      undef :puts
      def puts(*)
        super
      end
    end
  end

  def test_migrator_with_duplicate_names
    e = assert_raises(SecondaryActiveRecord::DuplicateMigrationNameError) do
      list = [SecondaryActiveRecord::Migration.new("Chunky"), SecondaryActiveRecord::Migration.new("Chunky")]
      SecondaryActiveRecord::Migrator.new(:up, list)
    end
    assert_match(/Multiple migrations have the name Chunky/, e.message)
  end

  def test_migrator_with_duplicate_versions
    assert_raises(SecondaryActiveRecord::DuplicateMigrationVersionError) do
      list = [SecondaryActiveRecord::Migration.new("Foo", 1), SecondaryActiveRecord::Migration.new("Bar", 1)]
      SecondaryActiveRecord::Migrator.new(:up, list)
    end
  end

  def test_migrator_with_missing_version_numbers
    assert_raises(SecondaryActiveRecord::UnknownMigrationVersionError) do
      list = [SecondaryActiveRecord::Migration.new("Foo", 1), SecondaryActiveRecord::Migration.new("Bar", 2)]
      SecondaryActiveRecord::Migrator.new(:up, list, 3).run
    end

    assert_raises(SecondaryActiveRecord::UnknownMigrationVersionError) do
      list = [SecondaryActiveRecord::Migration.new("Foo", 1), SecondaryActiveRecord::Migration.new("Bar", 2)]
      SecondaryActiveRecord::Migrator.new(:up, list, -1).run
    end

    assert_raises(SecondaryActiveRecord::UnknownMigrationVersionError) do
      list = [SecondaryActiveRecord::Migration.new("Foo", 1), SecondaryActiveRecord::Migration.new("Bar", 2)]
      SecondaryActiveRecord::Migrator.new(:up, list, 0).run
    end

    assert_raises(SecondaryActiveRecord::UnknownMigrationVersionError) do
      list = [SecondaryActiveRecord::Migration.new("Foo", 1), SecondaryActiveRecord::Migration.new("Bar", 2)]
      SecondaryActiveRecord::Migrator.new(:up, list, 3).migrate
    end

    assert_raises(SecondaryActiveRecord::UnknownMigrationVersionError) do
      list = [SecondaryActiveRecord::Migration.new("Foo", 1), SecondaryActiveRecord::Migration.new("Bar", 2)]
      SecondaryActiveRecord::Migrator.new(:up, list, -1).migrate
    end
  end

  def test_finds_migrations
    migrations = SecondaryActiveRecord::MigrationContext.new(MIGRATIONS_ROOT + "/valid").migrations

    [[1, "ValidPeopleHaveLastNames"], [2, "WeNeedReminders"], [3, "InnocentJointable"]].each_with_index do |pair, i|
      assert_equal migrations[i].version, pair.first
      assert_equal migrations[i].name, pair.last
    end
  end

  def test_finds_migrations_in_subdirectories
    migrations = SecondaryActiveRecord::MigrationContext.new(MIGRATIONS_ROOT + "/valid_with_subdirectories").migrations


    [[1, "ValidPeopleHaveLastNames"], [2, "WeNeedReminders"], [3, "InnocentJointable"]].each_with_index do |pair, i|
      assert_equal migrations[i].version, pair.first
      assert_equal migrations[i].name, pair.last
    end
  end

  def test_finds_migrations_from_two_directories
    directories = [MIGRATIONS_ROOT + "/valid_with_timestamps", MIGRATIONS_ROOT + "/to_copy_with_timestamps"]
    migrations = SecondaryActiveRecord::MigrationContext.new(directories).migrations

    [[20090101010101, "PeopleHaveHobbies"],
     [20090101010202, "PeopleHaveDescriptions"],
     [20100101010101, "ValidWithTimestampsPeopleHaveLastNames"],
     [20100201010101, "ValidWithTimestampsWeNeedReminders"],
     [20100301010101, "ValidWithTimestampsInnocentJointable"]].each_with_index do |pair, i|
       assert_equal pair.first, migrations[i].version
       assert_equal pair.last, migrations[i].name
     end
  end

  def test_finds_migrations_in_numbered_directory
    migrations = SecondaryActiveRecord::MigrationContext.new(MIGRATIONS_ROOT + "/10_urban").migrations
    assert_equal 9, migrations[0].version
    assert_equal "AddExpressions", migrations[0].name
  end

  def test_relative_migrations
    list = Dir.chdir(MIGRATIONS_ROOT) do
      SecondaryActiveRecord::MigrationContext.new("valid").migrations
    end

    migration_proxy = list.find { |item|
      item.name == "ValidPeopleHaveLastNames"
    }
    assert migration_proxy, "should find pending migration"
  end

  def test_finds_pending_migrations
    SecondaryActiveRecord::SchemaMigration.create!(version: "1")
    migration_list = [SecondaryActiveRecord::Migration.new("foo", 1), SecondaryActiveRecord::Migration.new("bar", 3)]
    migrations = SecondaryActiveRecord::Migrator.new(:up, migration_list).pending_migrations

    assert_equal 1, migrations.size
    assert_equal migration_list.last, migrations.first
  end

  def test_migrations_status
    path = MIGRATIONS_ROOT + "/valid"

    SecondaryActiveRecord::SchemaMigration.create(version: 2)
    SecondaryActiveRecord::SchemaMigration.create(version: 10)

    assert_equal [
      ["down", "001", "Valid people have last names"],
      ["up",   "002", "We need reminders"],
      ["down", "003", "Innocent jointable"],
      ["up",   "010", "********** NO FILE **********"],
    ], SecondaryActiveRecord::MigrationContext.new(path).migrations_status
  end

  def test_migrations_status_in_subdirectories
    path = MIGRATIONS_ROOT + "/valid_with_subdirectories"

    SecondaryActiveRecord::SchemaMigration.create(version: 2)
    SecondaryActiveRecord::SchemaMigration.create(version: 10)

    assert_equal [
      ["down", "001", "Valid people have last names"],
      ["up",   "002", "We need reminders"],
      ["down", "003", "Innocent jointable"],
      ["up",   "010", "********** NO FILE **********"],
    ], SecondaryActiveRecord::MigrationContext.new(path).migrations_status
  end

  def test_migrations_status_with_schema_define_in_subdirectories
    path = MIGRATIONS_ROOT + "/valid_with_subdirectories"
    prev_paths = SecondaryActiveRecord::Migrator.migrations_paths
    SecondaryActiveRecord::Migrator.migrations_paths = path

    SecondaryActiveRecord::Schema.define(version: 3) do
    end

    assert_equal [
      ["up", "001", "Valid people have last names"],
      ["up", "002", "We need reminders"],
      ["up", "003", "Innocent jointable"],
    ], SecondaryActiveRecord::MigrationContext.new(path).migrations_status
  ensure
    SecondaryActiveRecord::Migrator.migrations_paths = prev_paths
  end

  def test_migrations_status_from_two_directories
    paths = [MIGRATIONS_ROOT + "/valid_with_timestamps", MIGRATIONS_ROOT + "/to_copy_with_timestamps"]

    SecondaryActiveRecord::SchemaMigration.create(version: "20100101010101")
    SecondaryActiveRecord::SchemaMigration.create(version: "20160528010101")

    assert_equal [
      ["down", "20090101010101", "People have hobbies"],
      ["down", "20090101010202", "People have descriptions"],
      ["up",   "20100101010101", "Valid with timestamps people have last names"],
      ["down", "20100201010101", "Valid with timestamps we need reminders"],
      ["down", "20100301010101", "Valid with timestamps innocent jointable"],
      ["up",   "20160528010101", "********** NO FILE **********"],
    ], SecondaryActiveRecord::MigrationContext.new(paths).migrations_status
  end

  def test_migrator_interleaved_migrations
    pass_one = [Sensor.new("One", 1)]

    SecondaryActiveRecord::Migrator.new(:up, pass_one).migrate
    assert pass_one.first.went_up
    assert_not pass_one.first.went_down

    pass_two = [Sensor.new("One", 1), Sensor.new("Three", 3)]
    SecondaryActiveRecord::Migrator.new(:up, pass_two).migrate
    assert_not pass_two[0].went_up
    assert pass_two[1].went_up
    assert pass_two.all? { |x| !x.went_down }

    pass_three = [Sensor.new("One", 1),
                  Sensor.new("Two", 2),
                  Sensor.new("Three", 3)]

    SecondaryActiveRecord::Migrator.new(:down, pass_three).migrate
    assert pass_three[0].went_down
    assert_not pass_three[1].went_down
    assert pass_three[2].went_down
  end

  def test_up_calls_up
    migrations = [Sensor.new(nil, 0), Sensor.new(nil, 1), Sensor.new(nil, 2)]
    migrator = SecondaryActiveRecord::Migrator.new(:up, migrations)
    migrator.migrate
    assert migrations.all?(&:went_up)
    assert migrations.all? { |m| !m.went_down }
    assert_equal 2, migrator.current_version
  end

  def test_down_calls_down
    test_up_calls_up

    migrations = [Sensor.new(nil, 0), Sensor.new(nil, 1), Sensor.new(nil, 2)]
    migrator = SecondaryActiveRecord::Migrator.new(:down, migrations)
    migrator.migrate
    assert migrations.all? { |m| !m.went_up }
    assert migrations.all?(&:went_down)
    assert_equal 0, migrator.current_version
  end

  def test_current_version
    SecondaryActiveRecord::SchemaMigration.create!(version: "1000")
    migrator = SecondaryActiveRecord::MigrationContext.new("sec_db/migrate")
    assert_equal 1000, migrator.current_version
  end

  def test_migrator_one_up
    calls, migrations = sensors(3)

    SecondaryActiveRecord::Migrator.new(:up, migrations, 1).migrate
    assert_equal [[:up, 1]], calls
    calls.clear

    SecondaryActiveRecord::Migrator.new(:up, migrations, 2).migrate
    assert_equal [[:up, 2]], calls
  end

  def test_migrator_one_down
    calls, migrations = sensors(3)

    SecondaryActiveRecord::Migrator.new(:up, migrations).migrate
    assert_equal [[:up, 1], [:up, 2], [:up, 3]], calls
    calls.clear

    SecondaryActiveRecord::Migrator.new(:down, migrations, 1).migrate

    assert_equal [[:down, 3], [:down, 2]], calls
  end

  def test_migrator_one_up_one_down
    calls, migrations = sensors(3)

    SecondaryActiveRecord::Migrator.new(:up, migrations, 1).migrate
    assert_equal [[:up, 1]], calls
    calls.clear

    SecondaryActiveRecord::Migrator.new(:down, migrations, 0).migrate
    assert_equal [[:down, 1]], calls
  end

  def test_migrator_double_up
    calls, migrations = sensors(3)
    migrator = SecondaryActiveRecord::Migrator.new(:up, migrations, 1)
    assert_equal(0, migrator.current_version)

    migrator.migrate
    assert_equal [[:up, 1]], calls
    calls.clear

    migrator.migrate
    assert_equal [], calls
  end

  def test_migrator_double_down
    calls, migrations = sensors(3)
    migrator = SecondaryActiveRecord::Migrator.new(:up, migrations, 1)

    assert_equal 0, migrator.current_version

    migrator.run
    assert_equal [[:up, 1]], calls
    calls.clear

    migrator = SecondaryActiveRecord::Migrator.new(:down, migrations, 1)
    migrator.run
    assert_equal [[:down, 1]], calls
    calls.clear

    migrator.run
    assert_equal [], calls

    assert_equal 0, migrator.current_version
  end

  def test_migrator_verbosity
    _, migrations = sensors(3)

    SecondaryActiveRecord::Migration.verbose = true
    SecondaryActiveRecord::Migrator.new(:up, migrations, 1).migrate
    assert_not_equal 0, SecondaryActiveRecord::Migration.message_count

    SecondaryActiveRecord::Migration.message_count = 0

    SecondaryActiveRecord::Migrator.new(:down, migrations, 0).migrate
    assert_not_equal 0, SecondaryActiveRecord::Migration.message_count
  end

  def test_migrator_verbosity_off
    _, migrations = sensors(3)

    SecondaryActiveRecord::Migration.verbose = false
    SecondaryActiveRecord::Migrator.new(:up, migrations, 1).migrate
    assert_equal 0, SecondaryActiveRecord::Migration.message_count
    SecondaryActiveRecord::Migrator.new(:down, migrations, 0).migrate
    assert_equal 0, SecondaryActiveRecord::Migration.message_count
  end

  def test_target_version_zero_should_run_only_once
    calls, migrations = sensors(3)

    # migrate up to 1
    SecondaryActiveRecord::Migrator.new(:up, migrations, 1).migrate
    assert_equal [[:up, 1]], calls
    calls.clear

    # migrate down to 0
    SecondaryActiveRecord::Migrator.new(:down, migrations, 0).migrate
    assert_equal [[:down, 1]], calls
    calls.clear

    # migrate down to 0 again
    SecondaryActiveRecord::Migrator.new(:down, migrations, 0).migrate
    assert_equal [], calls
  end

  def test_migrator_going_down_due_to_version_target
    calls, migrator = migrator_class(3)
    migrator = migrator.new("valid")

    migrator.up(1)
    assert_equal [[:up, 1]], calls
    calls.clear

    migrator.migrate(0)
    assert_equal [[:down, 1]], calls
    calls.clear

    migrator.migrate
    assert_equal [[:up, 1], [:up, 2], [:up, 3]], calls
  end

  def test_migrator_output_when_running_multiple_migrations
    _, migrator = migrator_class(3)
    migrator = migrator.new("valid")

    result = migrator.migrate
    assert_equal(3, result.count)

    # Nothing migrated from duplicate run
    result = migrator.migrate
    assert_equal(0, result.count)

    result = migrator.rollback
    assert_equal(1, result.count)
  end

  def test_migrator_output_when_running_single_migration
    _, migrator = migrator_class(1)
    migrator = migrator.new("valid")

    result = migrator.run(:up, 1)

    assert_equal(1, result.version)
  end

  def test_migrator_rollback
    _, migrator = migrator_class(3)
    migrator = migrator.new("valid")

    migrator.migrate
    assert_equal(3, migrator.current_version)

    migrator.rollback
    assert_equal(2, migrator.current_version)

    migrator.rollback
    assert_equal(1, migrator.current_version)

    migrator.rollback
    assert_equal(0, migrator.current_version)

    migrator.rollback
    assert_equal(0, migrator.current_version)
  end

  def test_migrator_db_has_no_schema_migrations_table
    _, migrator = migrator_class(3)
    migrator = migrator.new("valid")

    SecondaryActiveRecord::Base.connection.drop_table "schema_migrations", if_exists: true
    assert_not SecondaryActiveRecord::Base.connection.table_exists?("schema_migrations")
    migrator.migrate(1)
    assert SecondaryActiveRecord::Base.connection.table_exists?("schema_migrations")
  end

  def test_migrator_forward
    _, migrator = migrator_class(3)
    migrator = migrator.new("/valid")
    migrator.migrate(1)
    assert_equal(1, migrator.current_version)

    migrator.forward(2)
    assert_equal(3, migrator.current_version)

    migrator.forward
    assert_equal(3, migrator.current_version)
  end

  def test_only_loads_pending_migrations
    # migrate up to 1
    SecondaryActiveRecord::SchemaMigration.create!(version: "1")

    calls, migrator = migrator_class(3)
    migrator = migrator.new("valid")
    migrator.migrate

    assert_equal [[:up, 2], [:up, 3]], calls
  end

  def test_get_all_versions
    _, migrator = migrator_class(3)
    migrator = migrator.new("valid")

    migrator.migrate
    assert_equal([1, 2, 3], migrator.get_all_versions)

    migrator.rollback
    assert_equal([1, 2], migrator.get_all_versions)

    migrator.rollback
    assert_equal([1], migrator.get_all_versions)

    migrator.rollback
    assert_equal([], migrator.get_all_versions)
  end

  private
    def m(name, version)
      x = Sensor.new name, version
      x.extend(Module.new {
        define_method(:up) { yield(:up, x); super() }
        define_method(:down) { yield(:down, x); super() }
      }) if block_given?
    end

    def sensors(count)
      calls = []
      migrations = count.times.map { |i|
        m(nil, i + 1) { |c, migration|
          calls << [c, migration.version]
        }
      }
      [calls, migrations]
    end

    def migrator_class(count)
      calls, migrations = sensors(count)

      migrator = Class.new(SecondaryActiveRecord::MigrationContext) {
        define_method(:migrations) { |*|
          migrations
        }
      }
      [calls, migrator]
    end
end
