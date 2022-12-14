# frozen_string_literal: true

require "rake/testtask"

require_relative "test/config"
require_relative "test/support/config"

def run_without_aborting(*tasks)
  errors = []

  tasks.each do |task|
    begin
      Rake::Task[task].invoke
    rescue Exception
      errors << task
    end
  end

  abort "Errors running #{errors.join(', ')}" if errors.any?
end

desc "Run mysql2, sqlite, and postgresql tests by default"
task default: :test

task :package

desc "Run mysql2, sqlite, and postgresql tests"
task :test do
  tasks = defined?(JRUBY_VERSION) ?
    %w(test_jdbcmysql test_jdbcsqlite3 test_jdbcpostgresql) :
    %w(test_mysql2 test_sqlite3 test_postgresql)
  run_without_aborting(*tasks)
end

namespace :test do
  task :isolated do
    tasks = defined?(JRUBY_VERSION) ?
      %w(isolated_test_jdbcmysql isolated_test_jdbcsqlite3 isolated_test_jdbcpostgresql) :
      %w(isolated_test_mysql2 isolated_test_sqlite3 isolated_test_postgresql)
    run_without_aborting(*tasks)
  end
end

desc "Build MySQL and PostgreSQL test databases"
namespace :sec_db do
  task create: ["sec_db:mysql:build", "sec_db:postgresql:build"]
  task drop: ["sec_db:mysql:drop", "sec_db:postgresql:drop"]
end

%w( mysql2 postgresql sqlite3 sqlite3_mem db2 oracle jdbcmysql jdbcpostgresql jdbcsqlite3 jdbcderby jdbch2 jdbchsqldb ).each do |adapter|
  namespace :test do
    Rake::TestTask.new(adapter => "#{adapter}:env") { |t|
      adapter_short = adapter == "db2" ? adapter : adapter[/^[a-z0-9]+/]
      t.libs << "test"
      t.test_files = (Dir.glob("test/cases/**/*_test.rb").reject {
        |x| x.include?("/adapters/")
      } + Dir.glob("test/cases/adapters/#{adapter_short}/**/*_test.rb"))

      t.warning = true
      t.verbose = true
      t.ruby_opts = ["--dev"] if defined?(JRUBY_VERSION)
    }

    namespace :isolated do
      task adapter => "#{adapter}:env" do
        adapter_short = adapter == "db2" ? adapter : adapter[/^[a-z0-9]+/]
        puts [adapter, adapter_short].inspect
        (Dir["test/cases/**/*_test.rb"].reject {
          |x| x.include?("/adapters/")
        } + Dir["test/cases/adapters/#{adapter_short}/**/*_test.rb"]).all? do |file|
          sh(Gem.ruby, "-w", "-Itest", file)
        end || raise("Failures")
      end
    end
  end

  namespace adapter do
    task test: "test_#{adapter}"
    task isolated_test: "isolated_test_#{adapter}"

    # Set the connection environment for the adapter
    task(:env) { ENV["ARCONN"] = adapter }
  end

  # Make sure the adapter test evaluates the env setting task
  task "test_#{adapter}" => ["#{adapter}:env", "test:#{adapter}"]
  task "isolated_test_#{adapter}" => ["#{adapter}:env", "test:isolated:#{adapter}"]
end

namespace :sec_db do
  namespace :mysql do
    desc "Build the MySQL test databases"
    task :build do
      config = ARTest.config["connections"]["mysql2"]
      %x( mysql --user=#{config["arunit"]["username"]} --password=#{config["arunit"]["password"]} -e "create DATABASE #{config["arunit"]["database"]} DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_unicode_ci ")
      %x( mysql --user=#{config["arunit2"]["username"]} --password=#{config["arunit2"]["password"]} -e "create DATABASE #{config["arunit2"]["database"]} DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_unicode_ci ")
    end

    desc "Drop the MySQL test databases"
    task :drop do
      config = ARTest.config["connections"]["mysql2"]
      %x( mysqladmin --user=#{config["arunit"]["username"]} --password=#{config["arunit"]["password"]} -f drop #{config["arunit"]["database"]} )
      %x( mysqladmin --user=#{config["arunit2"]["username"]} --password=#{config["arunit2"]["password"]} -f drop #{config["arunit2"]["database"]} )
    end

    desc "Rebuild the MySQL test databases"
    task rebuild: [:drop, :build]
  end

  namespace :postgresql do
    desc "Build the PostgreSQL test databases"
    task :build do
      config = ARTest.config["connections"]["postgresql"]
      %x( createdb -E UTF8 -T template0 #{config["arunit"]["database"]} )
      %x( createdb -E UTF8 -T template0 #{config["arunit2"]["database"]} )
    end

    desc "Drop the PostgreSQL test databases"
    task :drop do
      config = ARTest.config["connections"]["postgresql"]
      %x( dropdb #{config["arunit"]["database"]} )
      %x( dropdb #{config["arunit2"]["database"]} )
    end

    desc "Rebuild the PostgreSQL test databases"
    task rebuild: [:drop, :build]
  end
end

task build_mysql_databases: "sec_db:mysql:build"
task drop_mysql_databases: "sec_db:mysql:drop"
task rebuild_mysql_databases: "sec_db:mysql:rebuild"

task build_postgresql_databases: "sec_db:postgresql:build"
task drop_postgresql_databases: "sec_db:postgresql:drop"
task rebuild_postgresql_databases: "sec_db:postgresql:rebuild"

task :lines do
  load File.expand_path("../tools/line_statistics", __dir__)
  files = FileList["lib/secondary_active_record/**/*.rb"]
  CodeTools::LineStatistics.new(files).print_loc
end
