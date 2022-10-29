# frozen_string_literal: true

require "cases/helper"
require "secondary_active_record/tasks/database_tasks"

if current_adapter?(:Mysql2Adapter)
  module SecondaryActiveRecord
    class MysqlDBCreateTest < SecondaryActiveRecord::TestCase
      def setup
        @connection    = stub(create_database: true)
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-sec-db"
        }

        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)

        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_establishes_connection_without_database
        SecondaryActiveRecord::Base.expects(:establish_connection).
          with("adapter" => "mysql2", "database" => nil)

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      def test_creates_database_with_no_default_options
        @connection.expects(:create_database).
          with("my-app-sec-db", {})

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      def test_creates_database_with_given_encoding
        @connection.expects(:create_database).
          with("my-app-sec-db", charset: "latin1")

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration.merge("encoding" => "latin1")
      end

      def test_creates_database_with_given_collation
        @connection.expects(:create_database).
          with("my-app-sec-db", collation: "latin1_swedish_ci")

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration.merge("collation" => "latin1_swedish_ci")
      end

      def test_establishes_connection_to_database
        SecondaryActiveRecord::Base.expects(:establish_connection).with(@configuration)

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      def test_when_database_created_successfully_outputs_info_to_stdout
        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration

        assert_equal "Created database 'my-app-sec-db'\n", $stdout.string
      end

      def test_create_when_database_exists_outputs_info_to_stderr
        SecondaryActiveRecord::Base.connection.stubs(:create_database).raises(
          SecondaryActiveRecord::Tasks::DatabaseAlreadyExists
        )

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration

        assert_equal "Database 'my-app-sec-db' already exists\n", $stderr.string
      end
    end

    class MysqlDBCreateWithInvalidPermissionsTest < SecondaryActiveRecord::TestCase
      def setup
        @connection    = stub("Connection", create_database: true)
        @error         = Mysql2::Error.new("Invalid permissions")
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-sec-db",
          "username" => "pat",
          "password" => "wossname"
        }

        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).raises(@error)

        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_raises_error
        assert_raises(Mysql2::Error) do
          SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration
        end
      end
    end

    class MySQLDBDropTest < SecondaryActiveRecord::TestCase
      def setup
        @connection    = stub(drop_database: true)
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-sec-db"
        }

        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)

        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_establishes_connection_to_mysql_database
        SecondaryActiveRecord::Base.expects(:establish_connection).with @configuration

        SecondaryActiveRecord::Tasks::DatabaseTasks.drop @configuration
      end

      def test_drops_database
        @connection.expects(:drop_database).with("my-app-sec-db")

        SecondaryActiveRecord::Tasks::DatabaseTasks.drop @configuration
      end

      def test_when_database_dropped_successfully_outputs_info_to_stdout
        SecondaryActiveRecord::Tasks::DatabaseTasks.drop @configuration

        assert_equal "Dropped database 'my-app-sec-db'\n", $stdout.string
      end
    end

    class MySQLPurgeTest < SecondaryActiveRecord::TestCase
      def setup
        @connection    = stub(recreate_database: true)
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "test-sec-db"
        }

        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)
      end

      def test_establishes_connection_to_the_appropriate_database
        SecondaryActiveRecord::Base.expects(:establish_connection).with(@configuration)

        SecondaryActiveRecord::Tasks::DatabaseTasks.purge @configuration
      end

      def test_recreates_database_with_no_default_options
        @connection.expects(:recreate_database).
          with("test-sec-db", {})

        SecondaryActiveRecord::Tasks::DatabaseTasks.purge @configuration
      end

      def test_recreates_database_with_the_given_options
        @connection.expects(:recreate_database).
          with("test-sec-db", charset: "latin", collation: "latin1_swedish_ci")

        SecondaryActiveRecord::Tasks::DatabaseTasks.purge @configuration.merge(
          "encoding" => "latin", "collation" => "latin1_swedish_ci")
      end
    end

    class MysqlDBCharsetTest < SecondaryActiveRecord::TestCase
      def setup
        @connection    = stub(create_database: true)
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-sec-db"
        }

        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)
      end

      def test_db_retrieves_charset
        @connection.expects(:charset)
        SecondaryActiveRecord::Tasks::DatabaseTasks.charset @configuration
      end
    end

    class MysqlDBCollationTest < SecondaryActiveRecord::TestCase
      def setup
        @connection    = stub(create_database: true)
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-sec-db"
        }

        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)
      end

      def test_db_retrieves_collation
        @connection.expects(:collation)
        SecondaryActiveRecord::Tasks::DatabaseTasks.collation @configuration
      end
    end

    class MySQLStructureDumpTest < SecondaryActiveRecord::TestCase
      def setup
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "test-sec-db"
        }
      end

      def test_structure_dump
        filename = "awesome-file.sql"
        Kernel.expects(:system).with("mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-sec-db").returns(true)

        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
      end

      def test_structure_dump_with_extra_flags
        filename = "awesome-file.sql"
        expected_command = ["mysqldump", "--noop", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-sec-db"]

        assert_called_with(Kernel, :system, expected_command, returns: true) do
          with_structure_dump_flags(["--noop"]) do
            SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
          end
        end
      end

      def test_structure_dump_with_ignore_tables
        filename = "awesome-file.sql"
        SecondaryActiveRecord::SchemaDumper.expects(:ignore_tables).returns(["foo", "bar"])

        Kernel.expects(:system).with("mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "--ignore-table=test-sec-db.foo", "--ignore-table=test-sec-db.bar", "test-db").returns(true)

        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
      end

      def test_warn_when_external_structure_dump_command_execution_fails
        filename = "awesome-file.sql"
        Kernel.expects(:system)
          .with("mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db")
          .returns(false)

        e = assert_raise(RuntimeError) {
          SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
        }
        assert_match(/^failed to execute: `mysqldump`$/, e.message)
      end

      def test_structure_dump_with_port_number
        filename = "awesome-file.sql"
        Kernel.expects(:system).with("mysqldump", "--port=10000", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db").returns(true)

        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(
          @configuration.merge("port" => 10000),
          filename)
      end

      def test_structure_dump_with_ssl
        filename = "awesome-file.sql"
        Kernel.expects(:system).with("mysqldump", "--ssl-ca=ca.crt", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db").returns(true)

        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(
          @configuration.merge("sslca" => "ca.crt"),
          filename)
      end

      private
        def with_structure_dump_flags(flags)
          old = SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump_flags
          SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = flags
          yield
        ensure
          SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = old
        end
    end

    class MySQLStructureLoadTest < SecondaryActiveRecord::TestCase
      def setup
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "test-db"
        }
      end

      def test_structure_load
        filename = "awesome-file.sql"
        expected_command = ["mysql", "--noop", "--execute", %{SET FOREIGN_KEY_CHECKS = 0; SOURCE #{filename}; SET FOREIGN_KEY_CHECKS = 1}, "--database", "test-db"]

        assert_called_with(Kernel, :system, expected_command, returns: true) do
          with_structure_load_flags(["--noop"]) do
            SecondaryActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
          end
        end
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
