# frozen_string_literal: true

require "cases/helper"
require "secondary_active_record/tasks/database_tasks"
require "pathname"

if current_adapter?(:SQLite3Adapter)
  module SecondaryActiveRecord
    class SqliteDBCreateTest < SecondaryActiveRecord::TestCase
      def setup
        @database      = "db_create.sqlite3"
        @connection    = stub :connection
        @configuration = {
          "adapter"  => "sqlite3",
          "database" => @database
        }

        File.stubs(:exist?).returns(false)
        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)

        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_db_checks_database_exists
        File.expects(:exist?).with(@database).returns(false)

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration, "/rails/root"
      end

      def test_when_db_created_successfully_outputs_info_to_stdout
        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration, "/rails/root"

        assert_equal "Created database '#{@database}'\n", $stdout.string
      end

      def test_db_create_when_file_exists
        File.stubs(:exist?).returns(true)

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration, "/rails/root"

        assert_equal "Database '#{@database}' already exists\n", $stderr.string
      end

      def test_db_create_with_file_does_nothing
        File.stubs(:exist?).returns(true)
        $stderr.stubs(:puts).returns(nil)

        SecondaryActiveRecord::Base.expects(:establish_connection).never

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration, "/rails/root"
      end

      def test_db_create_establishes_a_connection
        SecondaryActiveRecord::Base.expects(:establish_connection).with(@configuration)

        SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration, "/rails/root"
      end

      def test_db_create_with_error_prints_message
        SecondaryActiveRecord::Base.stubs(:establish_connection).raises(Exception)

        $stderr.stubs(:puts).returns(true)
        $stderr.expects(:puts).
          with("Couldn't create database for #{@configuration.inspect}")

        assert_raises(Exception) { SecondaryActiveRecord::Tasks::DatabaseTasks.create @configuration, "/rails/root" }
      end
    end

    class SqliteDBDropTest < SecondaryActiveRecord::TestCase
      def setup
        @database      = "db_create.sqlite3"
        @path          = stub(to_s: "/absolute/path", absolute?: true)
        @configuration = {
          "adapter"  => "sqlite3",
          "database" => @database
        }

        Pathname.stubs(:new).returns(@path)
        File.stubs(:join).returns("/former/relative/path")
        FileUtils.stubs(:rm).returns(true)

        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_creates_path_from_database
        Pathname.expects(:new).with(@database).returns(@path)

        SecondaryActiveRecord::Tasks::DatabaseTasks.drop @configuration, "/rails/root"
      end

      def test_removes_file_with_absolute_path
        File.stubs(:exist?).returns(true)
        @path.stubs(:absolute?).returns(true)

        FileUtils.expects(:rm).with("/absolute/path")

        SecondaryActiveRecord::Tasks::DatabaseTasks.drop @configuration, "/rails/root"
      end

      def test_generates_absolute_path_with_given_root
        @path.stubs(:absolute?).returns(false)

        File.expects(:join).with("/rails/root", @path).
          returns("/former/relative/path")

        SecondaryActiveRecord::Tasks::DatabaseTasks.drop @configuration, "/rails/root"
      end

      def test_removes_file_with_relative_path
        File.stubs(:exist?).returns(true)
        @path.stubs(:absolute?).returns(false)

        FileUtils.expects(:rm).with("/former/relative/path")

        SecondaryActiveRecord::Tasks::DatabaseTasks.drop @configuration, "/rails/root"
      end

      def test_when_db_dropped_successfully_outputs_info_to_stdout
        SecondaryActiveRecord::Tasks::DatabaseTasks.drop @configuration, "/rails/root"

        assert_equal "Dropped database '#{@database}'\n", $stdout.string
      end
    end

    class SqliteDBCharsetTest < SecondaryActiveRecord::TestCase
      def setup
        @database      = "db_create.sqlite3"
        @connection    = stub :connection
        @configuration = {
          "adapter"  => "sqlite3",
          "database" => @database
        }

        File.stubs(:exist?).returns(false)
        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)
      end

      def test_db_retrieves_charset
        @connection.expects(:encoding)
        SecondaryActiveRecord::Tasks::DatabaseTasks.charset @configuration, "/rails/root"
      end
    end

    class SqliteDBCollationTest < SecondaryActiveRecord::TestCase
      def setup
        @database      = "db_create.sqlite3"
        @connection    = stub :connection
        @configuration = {
          "adapter"  => "sqlite3",
          "database" => @database
        }

        File.stubs(:exist?).returns(false)
        SecondaryActiveRecord::Base.stubs(:connection).returns(@connection)
        SecondaryActiveRecord::Base.stubs(:establish_connection).returns(true)
      end

      def test_db_retrieves_collation
        assert_raise NoMethodError do
          SecondaryActiveRecord::Tasks::DatabaseTasks.collation @configuration, "/rails/root"
        end
      end
    end

    class SqliteStructureDumpTest < SecondaryActiveRecord::TestCase
      def setup
        @database      = "db_create.sqlite3"
        @configuration = {
          "adapter"  => "sqlite3",
          "database" => @database
        }

        `sqlite3 #{@database} 'CREATE TABLE bar(id INTEGER)'`
        `sqlite3 #{@database} 'CREATE TABLE foo(id INTEGER)'`
      end

      def test_structure_dump
        dbfile   = @database
        filename = "awesome-file.sql"

        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump @configuration, filename, "/rails/root"
        assert File.exist?(dbfile)
        assert File.exist?(filename)
        assert_match(/CREATE TABLE foo/, File.read(filename))
        assert_match(/CREATE TABLE bar/, File.read(filename))
      ensure
        FileUtils.rm_f(filename)
        FileUtils.rm_f(dbfile)
      end

      def test_structure_dump_with_ignore_tables
        dbfile   = @database
        filename = "awesome-file.sql"
        SecondaryActiveRecord::SchemaDumper.expects(:ignore_tables).returns(["foo"])

        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename, "/rails/root")
        assert File.exist?(dbfile)
        assert File.exist?(filename)
        assert_match(/bar/, File.read(filename))
        assert_no_match(/foo/, File.read(filename))
      ensure
        FileUtils.rm_f(filename)
        FileUtils.rm_f(dbfile)
      end

      def test_structure_dump_execution_fails
        dbfile   = @database
        filename = "awesome-file.sql"
        Kernel.expects(:system).with("sqlite3", "--noop", "db_create.sqlite3", ".schema", out: "awesome-file.sql").returns(nil)

        e = assert_raise(RuntimeError) do
          with_structure_dump_flags(["--noop"]) do
            quietly { SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename, "/rails/root") }
          end
        end
        assert_match("failed to execute:", e.message)
      ensure
        FileUtils.rm_f(filename)
        FileUtils.rm_f(dbfile)
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

    class SqliteStructureLoadTest < SecondaryActiveRecord::TestCase
      def setup
        @database      = "db_create.sqlite3"
        @configuration = {
          "adapter"  => "sqlite3",
          "database" => @database
        }
      end

      def test_structure_load
        dbfile   = @database
        filename = "awesome-file.sql"

        open(filename, "w") { |f| f.puts("select datetime('now', 'localtime');") }
        SecondaryActiveRecord::Tasks::DatabaseTasks.structure_load @configuration, filename, "/rails/root"
        assert File.exist?(dbfile)
      ensure
        FileUtils.rm_f(filename)
        FileUtils.rm_f(dbfile)
      end
    end
  end
end
