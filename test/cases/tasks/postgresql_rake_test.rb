# frozen_string_literal: true

require "cases/helper"
require "secondary_active_record/tasks/database_tasks"

if current_adapter?(:PostgreSQLAdapter)
  module SecondaryActiveRecord
    class PostgreSQLDBCreateTest < SecondaryActiveRecord::TestCase
      def setup
        @connection    = stub(create_database: true)
        @configuration = {
          "adapter"  => "postgresql",
          "database" => "my-app-db"
        }

        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)

        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_establishes_connection_to_postgresql_database
        SecondaryActiveRecord::Base.expects(:establish_connection).with(
          "adapter"            => "postgresql",
          "database"           => "postgres",
          "schema_search_path" => "public"
        )

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      def test_creates_database_with_default_encoding
        @connection.expects(:create_database).
          with("my-app-db", @configuration.merge("encoding" => "utf8"))

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      def test_creates_database_with_given_encoding
        @connection.expects(:create_database).
          with("my-app-db", @configuration.merge("encoding" => "latin"))

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration.
          merge("encoding" => "latin")
      end

      def test_creates_database_with_given_collation_and_ctype
        @connection.expects(:create_database).
          with("my-app-db", @configuration.merge("encoding" => "utf8", "collation" => "ja_JP.UTF8", "ctype" => "ja_JP.UTF8"))

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration.
          merge("collation" => "ja_JP.UTF8", "ctype" => "ja_JP.UTF8")
      end

      def test_establishes_connection_to_new_database
        SecondaryActiveRecord::Base.expects(:establish_connection).with(@configuration)

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      def test_db_create_with_error_prints_message
        SecondaryActiveRecord::Base.stubs(:establish_connection).raises(Exception)

        $stderr.stubs(:puts).returns(true)
        $stderr.expects(:puts).
          with("Couldn't create database for #{@configuration.inspect}")

        assert_raises(Exception) { SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration }
      end

      def test_when_database_created_successfully_outputs_info_to_stdout
        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration

        assert_equal "Created database 'my-app-db'\n", $stdout.string
      end

      def test_create_when_database_exists_outputs_info_to_stderr
        SecondaryActiveRecord::Base.connection.stubs(:create_database).raises(
          SecondaryActiveRecord::Tasks::DatabaseAlreadyExists
        )

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration

        assert_equal "Database 'my-app-db' already exists\n", $stderr.string
      end
    end

    class PostgreSQLDBDropTest < SecondaryActiveRecord::TestCase
      def setup
        @connection    = stub(drop_database: true)
        @configuration = {
          "adapter"  => "postgresql",
          "database" => "my-app-db"
        }

        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)

        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_establishes_connection_to_postgresql_database
        SecondaryActiveRecord::Base.expects(:establish_connection).with(
          "adapter"            => "postgresql",
          "database"           => "postgres",
          "schema_search_path" => "public"
        )

        SecondaryActiveRecord::Tasks::DatabaseTasks.drop @configuration
      end

      def test_drops_database
        @connection.expects(:drop_database).with("my-app-db")

        SecondaryActiveRecord::Tasks::DatabaseTasks.drop @configuration
      end

      def test_when_database_dropped_successfully_outputs_info_to_stdout
        SecondaryActiveRecord::Tasks::DatabaseTasks.drop @configuration

        assert_equal "Dropped database 'my-app-db'\n", $stdout.string
      end
    end

    class PostgreSQLPurgeTest < SecondaryActiveRecord::TestCase
      def setup
        @connection    = stub(create_database: true, drop_database: true)
        @configuration = {
          "adapter"  => "postgresql",
          "database" => "my-app-db"
        }

        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:clear_active_connections!).returns(true)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)
      end

      def test_clears_active_connections
        SecondaryActiveRecord::Base.expects(:clear_active_connections!)

        SecondaryActiveRecord::Tasks::DatabaseTasks.purge @configuration
      end

      def test_establishes_connection_to_postgresql_database
        SecondaryActiveRecord::Base.expects(:establish_connection).with(
          "adapter"            => "postgresql",
          "database"           => "postgres",
          "schema_search_path" => "public"
        )

        SecondaryActiveRecord::Tasks::DatabaseTasks.purge @configuration
      end

      def test_drops_database
        @connection.expects(:drop_database).with("my-app-db")

        SecondaryActiveRecord::Tasks::DatabaseTasks.purge @configuration
      end

      def test_creates_database
        @connection.expects(:create_database).
          with("my-app-db", @configuration.merge("encoding" => "utf8"))

        SecondaryActiveRecord::Tasks::DatabaseTasks.purge @configuration
      end

      def test_establishes_connection
        SecondaryActiveRecord::Base.expects(:establish_connection).with(@configuration)

        SecondaryActiveRecord::Tasks::DatabaseTasks.purge @configuration
      end
    end

    class PostgreSQLDBCharsetTest < SecondaryActiveRecord::TestCase
      def setup
        @connection    = stub(create_database: true)
        @configuration = {
          "adapter"  => "postgresql",
          "database" => "my-app-db"
        }

        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)
      end

      def test_db_retrieves_charset
        @connection.expects(:encoding)
        SecondaryActiveRecord::Tasks::DatabaseTasks.charset @configuration
      end
    end

    class PostgreSQLDBCollationTest < SecondaryActiveRecord::TestCase
      def setup
        @connection    = stub(create_database: true)
        @configuration = {
          "adapter"  => "postgresql",
          "database" => "my-app-db"
        }

        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)
      end

      def test_db_retrieves_collation
        @connection.expects(:collation)
        SecondaryActiveRecord::Tasks::DatabaseTasks.collation @configuration
      end
    end

    class PostgreSQLStructureDumpTest < SecondaryActiveRecord::TestCase
      def setup
        @connection    = stub(schema_search_path: nil, structure_dump: true)
        @configuration = {
          "adapter"  => "postgresql",
          "database" => "my-app-db"
        }
        @filename = "/tmp/awesome-file.sql"
        FileUtils.touch(@filename)

        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)
      end

      def teardown
        FileUtils.rm_f(@filename)
      end

      def test_structure_dump
        Kernel.expects(:system).with("pg_dump", "-s", "-x", "-O", "-f", @filename, "my-app-db").returns(true)

        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
      end

      def test_structure_dump_header_comments_removed
        Kernel.stubs(:system).returns(true)
        File.write(@filename, "-- header comment\n\n-- more header comment\n statement \n-- lower comment\n")

        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)

        assert_equal [" statement \n", "-- lower comment\n"], File.readlines(@filename).first(2)
      end

      def test_structure_dump_with_extra_flags
        expected_command = ["pg_dump", "-s", "-x", "-O", "-f", @filename, "--noop", "my-app-db"]

        assert_called_with(Kernel, :system, expected_command, returns: true) do
          with_structure_dump_flags(["--noop"]) do
            SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
          end
        end
      end

      def test_structure_dump_with_ignore_tables
        SecondaryActiveRecord::SchemaDumper.expects(:ignore_tables).returns(["foo", "bar"])

        Kernel.expects(:system).with("pg_dump", "-s", "-x", "-O", "-f", @filename, "-T", "foo", "-T", "bar", "my-app-db").returns(true)

        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
      end

      def test_structure_dump_with_schema_search_path
        @configuration["schema_search_path"] = "foo,bar"

        Kernel.expects(:system).with("pg_dump", "-s", "-x", "-O", "-f", @filename, "--schema=foo", "--schema=bar", "my-app-db").returns(true)

        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
      end

      def test_structure_dump_with_schema_search_path_and_dump_schemas_all
        @configuration["schema_search_path"] = "foo,bar"

        Kernel.expects(:system).with("pg_dump", "-s", "-x", "-O", "-f", @filename,  "my-app-db").returns(true)

        with_dump_schemas(:all) do
          SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
        end
      end

      def test_structure_dump_with_dump_schemas_string
        Kernel.expects(:system).with("pg_dump", "-s", "-x", "-O", "-f", @filename, "--schema=foo", "--schema=bar", "my-app-db").returns(true)

        with_dump_schemas("foo,bar") do
          SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
        end
      end

      def test_structure_dump_execution_fails
        filename = "awesome-file.sql"
        Kernel.expects(:system).with("pg_dump", "-s", "-x", "-O", "-f", filename, "my-app-db").returns(nil)

        e = assert_raise(RuntimeError) do
          SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
        end
        assert_match("failed to execute:", e.message)
      end

      private
        def with_dump_schemas(value, &block)
          old_dump_schemas = SecondaryActiveRecord::Base.dump_schemas
          SecondaryActiveRecord::Base.dump_schemas = value
          yield
        ensure
          SecondaryActiveRecord::Base.dump_schemas = old_dump_schemas
        end

        def with_structure_dump_flags(flags)
          old = SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump_flags
          SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = flags
          yield
        ensure
          SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = old
        end
    end

    class PostgreSQLStructureLoadTest < SecondaryActiveRecord::TestCase
      def setup
        @connection    = stub
        @configuration = {
          "adapter"  => "postgresql",
          "database" => "my-app-db"
        }

        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)
      end

      def test_structure_load
        filename = "awesome-file.sql"
        Kernel.expects(:system).with("psql", "-v", "ON_ERROR_STOP=1", "-q", "-f", filename, @configuration["database"]).returns(true)

        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
      end

      def test_structure_load_with_extra_flags
        filename = "awesome-file.sql"
        expected_command = ["psql", "-v", "ON_ERROR_STOP=1", "-q", "-f", filename, "--noop", @configuration["database"]]

        assert_called_with(Kernel, :system, expected_command, returns: true) do
          with_structure_load_flags(["--noop"]) do
            SecondaryActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
          end
        end
      end

      def test_structure_load_accepts_path_with_spaces
        filename = "awesome file.sql"
        Kernel.expects(:system).with("psql", "-v", "ON_ERROR_STOP=1", "-q", "-f", filename, @configuration["database"]).returns(true)

        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
      end

      private
        def with_structure_load_flags(flags)
          old = SecondaryActiveRecord::Tasks::DatabaseTasks.structure_load_flags
          SecondaryActiveRecord::Tasks::DatabaseTasks.structure_load_flags = flags
          yield
        ensure
          SecondaryActiveRecord::Tasks::DatabaseTasks.structure_load_flags = old
        end
    end
  end
end
