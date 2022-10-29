# frozen_string_literal: true

require "cases/helper"
require "secondary_active_record/tasks/database_tasks"

module SecondaryActiveRecord
  module DatabaseTasksSetupper
    def setup
      @mysql_tasks, @postgresql_tasks, @sqlite_tasks = stub, stub, stub
      SecondaryActiveRecord::Tasks::MySQLDatabaseTasks.stubs(:new).returns @mysql_tasks
      SecondaryActiveRecord::Tasks::PostgreSQLDatabaseTasks.stubs(:new).returns @postgresql_tasks
      SecondaryActiveRecord::Tasks::SQLiteDatabaseTasks.stubs(:new).returns @sqlite_tasks

      $stdout, @original_stdout = StringIO.new, $stdout
      $stderr, @original_stderr = StringIO.new, $stderr
    end

    def teardown
      $stdout, $stderr = @original_stdout, @original_stderr
    end
  end

  ADAPTERS_TASKS = {
    mysql2:     :mysql_tasks,
    postgresql: :postgresql_tasks,
    sqlite3:    :sqlite_tasks
  }

  class DatabaseTasksUtilsTask < SecondaryActiveRecord::TestCase
    def test_raises_an_error_when_called_with_protected_environment
      SecondaryActiveRecord::MigrationContext.any_instance.stubs(:current_version).returns(1)

      protected_environments = SecondaryActiveRecord::Base.protected_environments
      current_env            = SecondaryActiveRecord::Base.connection.migration_context.current_environment
      assert_not_includes protected_environments, current_env
      # Assert no error
      SecondaryActiveRecord::Tasks::DatabaseTasks.check_protected_environments!

      SecondaryActiveRecord::Base.protected_environments = [current_env]
      assert_raise(SecondaryActiveRecord::ProtectedEnvironmentError) do
        SecondaryActiveRecord::Tasks::DatabaseTasks.check_protected_environments!
      end
    ensure
      SecondaryActiveRecord::Base.protected_environments = protected_environments
    end

    def test_raises_an_error_when_called_with_protected_environment_which_name_is_a_symbol
      SecondaryActiveRecord::MigrationContext.any_instance.stubs(:current_version).returns(1)

      protected_environments = SecondaryActiveRecord::Base.protected_environments
      current_env            = SecondaryActiveRecord::Base.connection.migration_context.current_environment
      assert_not_includes protected_environments, current_env
      # Assert no error
      SecondaryActiveRecord::Tasks::DatabaseTasks.check_protected_environments!

      SecondaryActiveRecord::Base.protected_environments = [current_env.to_sym]
      assert_raise(SecondaryActiveRecord::ProtectedEnvironmentError) do
        SecondaryActiveRecord::Tasks::DatabaseTasks.check_protected_environments!
      end
    ensure
      SecondaryActiveRecord::Base.protected_environments = protected_environments
    end

    def test_raises_an_error_if_no_migrations_have_been_made
      SecondaryActiveRecord::InternalMetadata.stubs(:table_exists?).returns(false)
      SecondaryActiveRecord::MigrationContext.any_instance.stubs(:current_version).returns(1)

      assert_raise(SecondaryActiveRecord::NoEnvironmentInSchemaError) do
        SecondaryActiveRecord::Tasks::DatabaseTasks.check_protected_environments!
      end
    end
  end

  class DatabaseTasksRegisterTask < SecondaryActiveRecord::TestCase
    def test_register_task
      klazz = Class.new do
        def initialize(*arguments); end
        def structure_dump(filename); end
      end
      instance = klazz.new

      klazz.stubs(:new).returns instance
      instance.expects(:structure_dump).with("awesome-file.sql", nil)

      SecondaryActiveRecord::Tasks::DatabaseTasks.register_task(/foo/, klazz)
      SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump({ "adapter" => :foo }, "awesome-file.sql")
    end

    def test_unregistered_task
      assert_raise(SecondaryActiveRecord::Tasks::DatabaseNotSupported) do
        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump({ "adapter" => :bar }, "awesome-file.sql")
      end
    end
  end

  class DatabaseTasksCreateTest < SecondaryActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_create") do
        eval("@#{v}").expects(:create)
        SecondaryActiveRecord::Tasks::DatabaseTasks.create "adapter" => k
      end
    end
  end

  class DatabaseTasksDumpSchemaCacheTest < SecondaryActiveRecord::TestCase
    def test_dump_schema_cache
      path = "/tmp/my_schema_cache.yml"
      SecondaryActiveRecord::Tasks::DatabaseTasks.dump_schema_cache(SecondaryActiveRecord::Base.connection, path)
      assert File.file?(path)
    ensure
      SecondaryActiveRecord::Base.clear_cache!
      FileUtils.rm_rf(path)
    end
  end

  class DatabaseTasksCreateAllTest < SecondaryActiveRecord::TestCase
    def setup
      @configurations = { "development" => { "database" => "my-db" } }

      SecondaryActiveRecord::Base.stubs(:configurations).returns(@configurations)
      # To refrain from connecting to a newly created empty DB in sqlite3_mem tests
      SecondaryActiveRecord::Base.connection_handler.stubs(:establish_connection)
    end

    def test_ignores_configurations_without_databases
      @configurations["development"].merge!("database" => nil)

      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:create).never

      SecondaryActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_ignores_remote_databases
      @configurations["development"].merge!("host" => "my.server.tld")
      $stderr.stubs(:puts).returns(nil)

      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:create).never

      SecondaryActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_warning_for_remote_databases
      @configurations["development"].merge!("host" => "my.server.tld")

      $stderr.expects(:puts).with("This task only modifies local databases. my-db is on a remote host.")

      SecondaryActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_creates_configurations_with_local_ip
      @configurations["development"].merge!("host" => "127.0.0.1")

      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:create)

      SecondaryActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_creates_configurations_with_local_host
      @configurations["development"].merge!("host" => "localhost")

      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:create)

      SecondaryActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_creates_configurations_with_blank_hosts
      @configurations["development"].merge!("host" => nil)

      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:create)

      SecondaryActiveRecord::Tasks::DatabaseTasks.create_all
    end
  end

  class DatabaseTasksCreateCurrentTest < SecondaryActiveRecord::TestCase
    def setup
      @configurations = {
        "development" => { "database" => "dev-db" },
        "test"        => { "database" => "test-db" },
        "production"  => { "database" => "prod-db" }
      }

      SecondaryActiveRecord::Base.stubs(:configurations).returns(@configurations)
      SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_creates_current_environment_database
      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:create).
        with("database" => "prod-db")

      SecondaryActiveRecord::Tasks::DatabaseTasks.create_current(
        ActiveSupport::StringInquirer.new("production")
      )
    end

    def test_creates_test_and_development_databases_when_env_was_not_specified
      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:create).
        with("database" => "dev-db")
      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:create).
        with("database" => "test-db")

      SecondaryActiveRecord::Tasks::DatabaseTasks.create_current(
        ActiveSupport::StringInquirer.new("development")
      )
    end

    def test_creates_test_and_development_databases_when_rails_env_is_development
      old_env = ENV["RAILS_ENV"]
      ENV["RAILS_ENV"] = "development"
      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:create).
        with("database" => "dev-db")
      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:create).
        with("database" => "test-db")

      SecondaryActiveRecord::Tasks::DatabaseTasks.create_current(
        ActiveSupport::StringInquirer.new("development")
      )
    ensure
      ENV["RAILS_ENV"] = old_env
    end

    def test_establishes_connection_for_the_given_environment
      SecondaryActiveRecord::Tasks::DatabaseTasks.stubs(:create).returns true

      SecondaryActiveRecord::Base.expects(:establish_connection).with(:development)

      SecondaryActiveRecord::Tasks::DatabaseTasks.create_current(
        ActiveSupport::StringInquirer.new("development")
      )
    end
  end

  class DatabaseTasksDropTest < SecondaryActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_drop") do
        eval("@#{v}").expects(:drop)
        SecondaryActiveRecord::Tasks::DatabaseTasks.drop "adapter" => k
      end
    end
  end

  class DatabaseTasksDropAllTest < SecondaryActiveRecord::TestCase
    def setup
      @configurations = { development: { "database" => "my-db" } }

      SecondaryActiveRecord::Base.stubs(:configurations).returns(@configurations)
    end

    def test_ignores_configurations_without_databases
      @configurations[:development].merge!("database" => nil)

      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:drop).never

      SecondaryActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_ignores_remote_databases
      @configurations[:development].merge!("host" => "my.server.tld")
      $stderr.stubs(:puts).returns(nil)

      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:drop).never

      SecondaryActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_warning_for_remote_databases
      @configurations[:development].merge!("host" => "my.server.tld")

      $stderr.expects(:puts).with("This task only modifies local databases. my-db is on a remote host.")

      SecondaryActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_drops_configurations_with_local_ip
      @configurations[:development].merge!("host" => "127.0.0.1")

      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:drop)

      SecondaryActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_drops_configurations_with_local_host
      @configurations[:development].merge!("host" => "localhost")

      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:drop)

      SecondaryActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_drops_configurations_with_blank_hosts
      @configurations[:development].merge!("host" => nil)

      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:drop)

      SecondaryActiveRecord::Tasks::DatabaseTasks.drop_all
    end
  end

  class DatabaseTasksDropCurrentTest < SecondaryActiveRecord::TestCase
    def setup
      @configurations = {
        "development" => { "database" => "dev-db" },
        "test"        => { "database" => "test-db" },
        "production"  => { "database" => "prod-db" }
      }

      SecondaryActiveRecord::Base.stubs(:configurations).returns(@configurations)
    end

    def test_drops_current_environment_database
      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:drop).
        with("database" => "prod-db")

      SecondaryActiveRecord::Tasks::DatabaseTasks.drop_current(
        ActiveSupport::StringInquirer.new("production")
      )
    end

    def test_drops_test_and_development_databases_when_env_was_not_specified
      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:drop).
        with("database" => "dev-db")
      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:drop).
        with("database" => "test-db")

      SecondaryActiveRecord::Tasks::DatabaseTasks.drop_current(
        ActiveSupport::StringInquirer.new("development")
      )
    end

    def test_drops_testand_development_databases_when_rails_env_is_development
      old_env = ENV["RAILS_ENV"]
      ENV["RAILS_ENV"] = "development"
      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:drop).
        with("database" => "dev-db")
      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:drop).
        with("database" => "test-db")

      SecondaryActiveRecord::Tasks::DatabaseTasks.drop_current(
        ActiveSupport::StringInquirer.new("development")
      )
    ensure
      ENV["RAILS_ENV"] = old_env
    end
  end

  if current_adapter?(:SQLite3Adapter) && !in_memory_db?
    class DatabaseTasksMigrateTest < SecondaryActiveRecord::TestCase
      self.use_transactional_tests = false

      # Use a memory db here to avoid having to rollback at the end
      setup do
        migrations_path = MIGRATIONS_ROOT + "/valid"
        file = SecondaryActiveRecord::Base.connection.raw_connection.filename
        @conn = SecondaryActiveRecord::Base.establish_connection adapter: "sqlite3",
          database: ":memory:", migrations_paths: migrations_path
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

      def test_migrate_set_and_unset_verbose_and_version_env_vars
        verbose, version = ENV["VERBOSE"], ENV["VERSION"]
        ENV["VERSION"] = "2"
        ENV["VERBOSE"] = "false"

        # run down migration because it was already run on copied db
        assert_empty capture_migration_output

        ENV.delete("VERSION")
        ENV.delete("VERBOSE")

        # re-run up migration
        assert_includes capture_migration_output, "migrating"
      ensure
        ENV["VERBOSE"], ENV["VERSION"] = verbose, version
      end

      def test_migrate_set_and_unset_empty_values_for_verbose_and_version_env_vars
        verbose, version = ENV["VERBOSE"], ENV["VERSION"]

        ENV["VERSION"] = "2"
        ENV["VERBOSE"] = "false"

        # run down migration because it was already run on copied db
        assert_empty capture_migration_output

        ENV["VERBOSE"] = ""
        ENV["VERSION"] = ""

        # re-run up migration
        assert_includes capture_migration_output, "migrating"
      ensure
        ENV["VERBOSE"], ENV["VERSION"] = verbose, version
      end

      def test_migrate_set_and_unset_nonsense_values_for_verbose_and_version_env_vars
        verbose, version = ENV["VERBOSE"], ENV["VERSION"]

        # run down migration because it was already run on copied db
        ENV["VERSION"] = "2"
        ENV["VERBOSE"] = "false"

        assert_empty capture_migration_output

        ENV["VERBOSE"] = "yes"
        ENV["VERSION"] = "2"

        # run no migration because 2 was already run
        assert_empty capture_migration_output
      ensure
        ENV["VERBOSE"], ENV["VERSION"] = verbose, version
      end

      private
        def capture_migration_output
          capture(:stdout) do
            SecondaryActiveRecord::Tasks::DatabaseTasks.migrate
          end
        end
    end
  end

  class DatabaseTasksMigrateErrorTest < SecondaryActiveRecord::TestCase
    self.use_transactional_tests = false

    def test_migrate_raise_error_on_invalid_version_format
      version = ENV["VERSION"]

      ENV["VERSION"] = "unknown"
      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "0.1.11"
      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1.1.11"
      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "0 "
      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1."
      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1_"
      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1_name"
      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_match(/Invalid format of target version/, e.message)
    ensure
      ENV["VERSION"] = version
    end

    def test_migrate_raise_error_on_failed_check_target_version
      SecondaryActiveRecord::Tasks::DatabaseTasks.stubs(:check_target_version).raises("foo")

      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_equal "foo", e.message
    end

    def test_migrate_clears_schema_cache_afterward
      SecondaryActiveRecord::Base.expects(:clear_cache!)
      SecondaryActiveRecord::Tasks::DatabaseTasks.migrate
    end
  end

  class DatabaseTasksPurgeTest < SecondaryActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_purge") do
        eval("@#{v}").expects(:purge)
        SecondaryActiveRecord::Tasks::DatabaseTasks.purge "adapter" => k
      end
    end
  end

  class DatabaseTasksPurgeCurrentTest < SecondaryActiveRecord::TestCase
    def test_purges_current_environment_database
      configurations = {
        "development" => { "database" => "dev-db" },
        "test"        => { "database" => "test-db" },
        "production"  => { "database" => "prod-db" }
      }
      SecondaryActiveRecord::Base.stubs(:configurations).returns(configurations)

      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:purge).
        with("database" => "prod-db")
      SecondaryActiveRecord::Base.expects(:establish_connection).with(:production)

      SecondaryActiveRecord::Tasks::DatabaseTasks.purge_current("production")
    end
  end

  class DatabaseTasksPurgeAllTest < SecondaryActiveRecord::TestCase
    def test_purge_all_local_configurations
      configurations = { development: { "database" => "my-db" } }
      SecondaryActiveRecord::Base.stubs(:configurations).returns(configurations)

      SecondaryActiveRecord::Tasks::DatabaseTasks.expects(:purge).
        with("database" => "my-db")

      SecondaryActiveRecord::Tasks::DatabaseTasks.purge_all
    end
  end

  class DatabaseTasksCharsetTest < SecondaryActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_charset") do
        eval("@#{v}").expects(:charset)
        SecondaryActiveRecord::Tasks::DatabaseTasks.charset "adapter" => k
      end
    end
  end

  class DatabaseTasksCollationTest < SecondaryActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_collation") do
        eval("@#{v}").expects(:collation)
        SecondaryActiveRecord::Tasks::DatabaseTasks.collation "adapter" => k
      end
    end
  end

  class DatabaseTaskTargetVersionTest < SecondaryActiveRecord::TestCase
    def test_target_version_returns_nil_if_version_does_not_exist
      version = ENV.delete("VERSION")
      assert_nil SecondaryActiveRecord::Tasks::DatabaseTasks.target_version
    ensure
      ENV["VERSION"] = version
    end

    def test_target_version_returns_nil_if_version_is_empty
      version = ENV["VERSION"]

      ENV["VERSION"] = ""
      assert_nil SecondaryActiveRecord::Tasks::DatabaseTasks.target_version
    ensure
      ENV["VERSION"] = version
    end

    def test_target_version_returns_converted_to_integer_env_version_if_version_exists
      version = ENV["VERSION"]

      ENV["VERSION"] = "0"
      assert_equal ENV["VERSION"].to_i, SecondaryActiveRecord::Tasks::DatabaseTasks.target_version

      ENV["VERSION"] = "42"
      assert_equal ENV["VERSION"].to_i, SecondaryActiveRecord::Tasks::DatabaseTasks.target_version

      ENV["VERSION"] = "042"
      assert_equal ENV["VERSION"].to_i, SecondaryActiveRecord::Tasks::DatabaseTasks.target_version
    ensure
      ENV["VERSION"] = version
    end
  end

  class DatabaseTaskCheckTargetVersionTest < SecondaryActiveRecord::TestCase
    def test_check_target_version_does_not_raise_error_on_empty_version
      version = ENV["VERSION"]
      ENV["VERSION"] = ""
      assert_nothing_raised { SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version }
    ensure
      ENV["VERSION"] = version
    end

    def test_check_target_version_does_not_raise_error_if_version_is_not_setted
      version = ENV.delete("VERSION")
      assert_nothing_raised { SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version }
    ensure
      ENV["VERSION"] = version
    end

    def test_check_target_version_raises_error_on_invalid_version_format
      version = ENV["VERSION"]

      ENV["VERSION"] = "unknown"
      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "0.1.11"
      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1.1.11"
      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "0 "
      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1."
      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1_"
      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1_name"
      e = assert_raise(RuntimeError) { SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version }
      assert_match(/Invalid format of target version/, e.message)
    ensure
      ENV["VERSION"] = version
    end

    def test_check_target_version_does_not_raise_error_on_valid_version_format
      version = ENV["VERSION"]

      ENV["VERSION"] = "0"
      assert_nothing_raised { SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version }

      ENV["VERSION"] = "1"
      assert_nothing_raised { SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version }

      ENV["VERSION"] = "001"
      assert_nothing_raised { SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version }

      ENV["VERSION"] = "001_name.rb"
      assert_nothing_raised { SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version }
    ensure
      ENV["VERSION"] = version
    end
  end

  class DatabaseTasksStructureDumpTest < SecondaryActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_structure_dump") do
        eval("@#{v}").expects(:structure_dump).with("awesome-file.sql", nil)
        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump({ "adapter" => k }, "awesome-file.sql")
      end
    end
  end

  class DatabaseTasksStructureLoadTest < SecondaryActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_structure_load") do
        eval("@#{v}").expects(:structure_load).with("awesome-file.sql", nil)
        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_load({ "adapter" => k }, "awesome-file.sql")
      end
    end
  end

  class DatabaseTasksCheckSchemaFileTest < SecondaryActiveRecord::TestCase
    def test_check_schema_file
      Kernel.expects(:abort).with(regexp_matches(/awesome-file.sql/))
      SecondaryActiveRecord::Tasks::DatabaseTasks.check_schema_file("awesome-file.sql")
    end
  end

  class DatabaseTasksCheckSchemaFileDefaultsTest < SecondaryActiveRecord::TestCase
    def test_check_schema_file_defaults
      SecondaryActiveRecord::Tasks::DatabaseTasks.stubs(:db_dir).returns("/tmp")
      assert_equal "/tmp/schema.rb", SecondaryActiveRecord::Tasks::DatabaseTasks.schema_file
    end
  end

  class DatabaseTasksCheckSchemaFileSpecifiedFormatsTest < SecondaryActiveRecord::TestCase
    { ruby: "schema.rb", sql: "structure.sql" }.each_pair do |fmt, filename|
      define_method("test_check_schema_file_for_#{fmt}_format") do
        SecondaryActiveRecord::Tasks::DatabaseTasks.stubs(:db_dir).returns("/tmp")
        assert_equal "/tmp/#{filename}", SecondaryActiveRecord::Tasks::DatabaseTasks.schema_file(fmt)
      end
    end
  end
end
