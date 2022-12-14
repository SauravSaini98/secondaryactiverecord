# frozen_string_literal: true

require "secondary_active_record"

db_namespace = namespace :sec_db do
  desc "Set the environment value for the database"
  task "environment:set" => :load_config do
    SecondaryActiveRecord::InternalMetadata.create_table
    SecondaryActiveRecord::InternalMetadata[:environment] = SecondaryActiveRecord::Base.connection.migration_context.current_environment
  end

  task check_protected_environments: :load_config do
    SecondaryActiveRecord::Tasks::DatabaseTasks.check_protected_environments!
  end

  task load_config: :environment do
    SecondaryActiveRecord::Base.configurations       = SecondaryActiveRecord::Tasks::DatabaseTasks.database_configuration || {}
    SecondaryActiveRecord::Migrator.migrations_paths = SecondaryActiveRecord::Tasks::DatabaseTasks.migrations_paths
  end

  namespace :create do
    task all: :load_config do
      SecondaryActiveRecord::Tasks::DatabaseTasks.create_all
    end
  end

  desc "Creates the database from DATABASE_URL or config/secondary_database.yml for the current RAILS_ENV (use sec_db:create:all to create all databases in the config). Without RAILS_ENV or when RAILS_ENV is development, it defaults to creating the development and test databases."
  task create: [:load_config] do
    SecondaryActiveRecord::Tasks::DatabaseTasks.create_current
  end

  namespace :drop do
    task all: [:load_config, :check_protected_environments] do
      SecondaryActiveRecord::Tasks::DatabaseTasks.drop_all
    end
  end

  desc "Drops the database from DATABASE_URL or config/secondary_database.yml for the current RAILS_ENV (use sec_db:drop:all to drop all databases in the config). Without RAILS_ENV or when RAILS_ENV is development, it defaults to dropping the development and test databases."
  task drop: [:load_config, :check_protected_environments] do
    db_namespace["drop:_unsafe"].invoke
  end

  task "drop:_unsafe" => [:load_config] do
    SecondaryActiveRecord::Tasks::DatabaseTasks.drop_current
  end

  namespace :purge do
    task all: [:load_config, :check_protected_environments] do
      SecondaryActiveRecord::Tasks::DatabaseTasks.purge_all
    end
  end

  # desc "Empty the database from DATABASE_URL or config/secondary_database.yml for the current RAILS_ENV (use sec_db:purge:all to purge all databases in the config). Without RAILS_ENV it defaults to purging the development and test databases."
  task purge: [:load_config, :check_protected_environments] do
    SecondaryActiveRecord::Tasks::DatabaseTasks.purge_current
  end

  desc "Migrate the database (options: VERSION=x, VERBOSE=false, SCOPE=blog)."
  task migrate: :load_config do
    SecondaryActiveRecord::Tasks::DatabaseTasks.migrate
    db_namespace["_dump"].invoke
  end

  # IMPORTANT: This task won't dump the schema if SecondaryActiveRecord::Base.dump_schema_after_migration is set to false
  task :_dump do
    if SecondaryActiveRecord::Base.dump_schema_after_migration
      case SecondaryActiveRecord::Base.schema_format
      when :ruby then db_namespace["schema:dump"].invoke
      when :sql  then db_namespace["structure:dump"].invoke
      else
        raise "unknown schema format #{SecondaryActiveRecord::Base.schema_format}"
      end
    end
    # Allow this task to be called as many times as required. An example is the
    # migrate:redo task, which calls other two internally that depend on this one.
    db_namespace["_dump"].reenable
  end

  namespace :migrate do
    # desc  'Rollbacks the database one migration and re migrate up (options: STEP=x, VERSION=x).'
    task redo: :load_config do
      raise "Empty VERSION provided" if ENV["VERSION"] && ENV["VERSION"].empty?

      if ENV["VERSION"]
        db_namespace["migrate:down"].invoke
        db_namespace["migrate:up"].invoke
      else
        db_namespace["rollback"].invoke
        db_namespace["migrate"].invoke
      end
    end

    # desc 'Resets your database using your migrations for the current environment'
    task reset: ["sec_db:drop", "sec_db:create", "sec_db:migrate"]

    # desc 'Runs the "up" for a given migration VERSION.'
    task up: :load_config do
      raise "VERSION is required" if !ENV["VERSION"] || ENV["VERSION"].empty?

      SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version

      SecondaryActiveRecord::Base.connection.migration_context.run(
        :up,
        SecondaryActiveRecord::Tasks::DatabaseTasks.target_version
      )
      db_namespace["_dump"].invoke
    end

    # desc 'Runs the "down" for a given migration VERSION.'
    task down: :load_config do
      raise "VERSION is required - To go down one migration, use sec_db:rollback" if !ENV["VERSION"] || ENV["VERSION"].empty?

      SecondaryActiveRecord::Tasks::DatabaseTasks.check_target_version

      SecondaryActiveRecord::Base.connection.migration_context.run(
        :down,
        SecondaryActiveRecord::Tasks::DatabaseTasks.target_version
      )
      db_namespace["_dump"].invoke
    end

    desc "Display status of migrations"
    task status: :load_config do
      unless SecondaryActiveRecord::SchemaMigration.table_exists?
        abort "Schema migrations table does not exist yet."
      end

      # output
      puts "\ndatabase: #{SecondaryActiveRecord::Base.connection_config[:database]}\n\n"
      puts "#{'Status'.center(8)}  #{'Migration ID'.ljust(14)}  Migration Name"
      puts "-" * 50
      SecondaryActiveRecord::Base.connection.migration_context.migrations_status.each do |status, version, name|
        puts "#{status.center(8)}  #{version.ljust(14)}  #{name}"
      end
      puts
    end
  end

  desc "Rolls the schema back to the previous version (specify steps w/ STEP=n)."
  task rollback: :load_config do
    step = ENV["STEP"] ? ENV["STEP"].to_i : 1
    SecondaryActiveRecord::Base.connection.migration_context.rollback(step)
    db_namespace["_dump"].invoke
  end

  # desc 'Pushes the schema to the next version (specify steps w/ STEP=n).'
  task forward: :load_config do
    step = ENV["STEP"] ? ENV["STEP"].to_i : 1
    SecondaryActiveRecord::Base.connection.migration_context.forward(step)
    db_namespace["_dump"].invoke
  end

  # desc 'Drops and recreates the database from db/schema.rb for the current environment and loads the seeds.'
  task reset: [ "db:drop", "db:setup" ]

  # desc "Retrieves the charset for the current environment's database"
  task charset: :load_config do
    puts SecondaryActiveRecord::Tasks::DatabaseTasks.charset_current
  end

  # desc "Retrieves the collation for the current environment's database"
  task collation: :load_config do
    begin
      puts SecondaryActiveRecord::Tasks::DatabaseTasks.collation_current
    rescue NoMethodError
      $stderr.puts "Sorry, your database adapter is not supported yet. Feel free to submit a patch."
    end
  end

  desc "Retrieves the current schema version number"
  task version: :load_config do
    puts "Current version: #{SecondaryActiveRecord::Base.connection.migration_context.current_version}"
  end

  # desc "Raises an error if there are pending migrations"
  task abort_if_pending_migrations: :load_config do
    pending_migrations = SecondaryActiveRecord::Base.connection.migration_context.open.pending_migrations

    if pending_migrations.any?
      puts "You have #{pending_migrations.size} pending #{pending_migrations.size > 1 ? 'migrations:' : 'migration:'}"
      pending_migrations.each do |pending_migration|
        puts "  %4d %s" % [pending_migration.version, pending_migration.name]
      end
      abort %{Run `rails db:migrate` to update your database then try again.}
    end
  end

  desc "Creates the database, loads the schema, and initializes with the seed data (use db:reset to also drop the database first)"
  task setup: ["db:schema:load_if_ruby", "db:structure:load_if_sql", :seed]

  desc "Loads the seed data from db/seeds.rb"
  task :seed do
    db_namespace["abort_if_pending_migrations"].invoke
    SecondaryActiveRecord::Tasks::DatabaseTasks.load_seed
  end

  namespace :fixtures do
    desc "Loads fixtures into the current environment's database. Load specific fixtures using FIXTURES=x,y. Load from subdirectory in test/fixtures using FIXTURES_DIR=z. Specify an alternative path (eg. spec/fixtures) using FIXTURES_PATH=spec/fixtures."
    task load: :load_config do
      require "secondary_active_record/fixtures"

      base_dir = SecondaryActiveRecord::Tasks::DatabaseTasks.fixtures_path

      fixtures_dir = if ENV["FIXTURES_DIR"]
        File.join base_dir, ENV["FIXTURES_DIR"]
      else
        base_dir
      end

      fixture_files = if ENV["FIXTURES"]
        ENV["FIXTURES"].split(",")
      else
        # The use of String#[] here is to support namespaced fixtures.
        Dir["#{fixtures_dir}/**/*.yml"].map { |f| f[(fixtures_dir.size + 1)..-5] }
      end

      SecondaryActiveRecord::FixtureSet.create_fixtures(fixtures_dir, fixture_files)
    end

    # desc "Search for a fixture given a LABEL or ID. Specify an alternative path (eg. spec/fixtures) using FIXTURES_PATH=spec/fixtures."
    task identify: :load_config do
      require "secondary_active_record/fixtures"

      label, id = ENV["LABEL"], ENV["ID"]
      raise "LABEL or ID required" if label.blank? && id.blank?

      puts %Q(The fixture ID for "#{label}" is #{SecondaryActiveRecord::FixtureSet.identify(label)}.) if label

      base_dir = SecondaryActiveRecord::Tasks::DatabaseTasks.fixtures_path

      Dir["#{base_dir}/**/*.yml"].each do |file|
        if data = YAML.load(ERB.new(IO.read(file)).result)
          data.each_key do |key|
            key_id = SecondaryActiveRecord::FixtureSet.identify(key)

            if key == label || key_id == id.to_i
              puts "#{file}: #{key} (#{key_id})"
            end
          end
        end
      end
    end
  end

  namespace :schema do
    desc "Creates a db/schema.rb file that is portable against any DB supported by Secondary Active Record"
    task dump: :load_config do
      require "secondary_active_record/schema_dumper"
      filename = ENV["SCHEMA"] || File.join(SecondaryActiveRecord::Tasks::DatabaseTasks.db_dir, "schema.rb")
      File.open(filename, "w:utf-8") do |file|
        SecondaryActiveRecord::SchemaDumper.dump(SecondaryActiveRecord::Base.connection, file)
      end
      db_namespace["schema:dump"].reenable
    end

    desc "Loads a schema.rb file into the database"
    task load: [:load_config, :check_protected_environments] do
      SecondaryActiveRecord::Tasks::DatabaseTasks.load_schema_current(:ruby, ENV["SCHEMA"])
    end

    task load_if_ruby: ["db:create", :environment] do
      db_namespace["schema:load"].invoke if SecondaryActiveRecord::Base.schema_format == :ruby
    end

    namespace :cache do
      desc "Creates a db/schema_cache.yml file."
      task dump: :load_config do
        conn = SecondaryActiveRecord::Base.connection
        filename = File.join(SecondaryActiveRecord::Tasks::DatabaseTasks.db_dir, "schema_cache.yml")
        SecondaryActiveRecord::Tasks::DatabaseTasks.dump_schema_cache(conn, filename)
      end

      desc "Clears a db/schema_cache.yml file."
      task clear: :load_config do
        filename = File.join(SecondaryActiveRecord::Tasks::DatabaseTasks.db_dir, "schema_cache.yml")
        rm_f filename, verbose: false
      end
    end

  end

  namespace :structure do
    desc "Dumps the database structure to db/structure.sql. Specify another file with SCHEMA=db/my_structure.sql"
    task dump: :load_config do
      filename = ENV["SCHEMA"] || File.join(SecondaryActiveRecord::Tasks::DatabaseTasks.db_dir, "structure.sql")
      current_config = SecondaryActiveRecord::Tasks::DatabaseTasks.current_config
      SecondaryActiveRecord::Tasks::DatabaseTasks.structure_dump(current_config, filename)

      if SecondaryActiveRecord::SchemaMigration.table_exists?
        File.open(filename, "a") do |f|
          f.puts SecondaryActiveRecord::Base.connection.dump_schema_information
          f.print "\n"
        end
      end
      db_namespace["structure:dump"].reenable
    end

    desc "Recreates the databases from the structure.sql file"
    task load: [:load_config, :check_protected_environments] do
      SecondaryActiveRecord::Tasks::DatabaseTasks.load_schema_current(:sql, ENV["SCHEMA"])
    end

    task load_if_sql: ["db:create", :environment] do
      db_namespace["structure:load"].invoke if SecondaryActiveRecord::Base.schema_format == :sql
    end
  end

  namespace :test do
    # desc "Recreate the test database from the current schema"
    task load: %w(db:test:purge) do
      case SecondaryActiveRecord::Base.schema_format
      when :ruby
        db_namespace["test:load_schema"].invoke
      when :sql
        db_namespace["test:load_structure"].invoke
      end
    end

    # desc "Recreate the test database from an existent schema.rb file"
    task load_schema: %w(db:test:purge) do
      begin
        should_reconnect = SecondaryActiveRecord::Base.connection_pool.active_connection?
        SecondaryActiveRecord::Schema.verbose = false
        SecondaryActiveRecord::Tasks::DatabaseTasks.load_schema SecondaryActiveRecord::Base.configurations["test"], :ruby, ENV["SCHEMA"], "test"
      ensure
        if should_reconnect
          SecondaryActiveRecord::Base.establish_connection(SecondaryActiveRecord::Base.configurations[SecondaryActiveRecord::Tasks::DatabaseTasks.env])
        end
      end
    end

    # desc "Recreate the test database from an existent structure.sql file"
    task load_structure: %w(db:test:purge) do
      SecondaryActiveRecord::Tasks::DatabaseTasks.load_schema SecondaryActiveRecord::Base.configurations["test"], :sql, ENV["SCHEMA"], "test"
    end

    # desc "Empty the test database"
    task purge: %w(load_config check_protected_environments) do
      SecondaryActiveRecord::Tasks::DatabaseTasks.purge SecondaryActiveRecord::Base.configurations["test"]
    end

    # desc 'Load the test schema'
    task prepare: :load_config do
      unless SecondaryActiveRecord::Base.configurations.blank?
        db_namespace["test:load"].invoke
      end
    end
  end
end

namespace :railties do
  namespace :install do
    # desc "Copies missing migrations from Railties (e.g. engines). You can specify Railties to use with FROM=railtie1,railtie2"
    task migrations: :'db:load_config' do
      to_load = ENV["FROM"].blank? ? :all : ENV["FROM"].split(",").map(&:strip)
      railties = {}
      Rails.application.migration_railties.each do |railtie|
        next unless to_load == :all || to_load.include?(railtie.railtie_name)

        if railtie.respond_to?(:paths) && (path = railtie.paths["db/migrate"].first)
          railties[railtie.railtie_name] = path
        end
      end

      on_skip = Proc.new do |name, migration|
        puts "NOTE: Migration #{migration.basename} from #{name} has been skipped. Migration with the same name already exists."
      end

      on_copy = Proc.new do |name, migration|
        puts "Copied migration #{migration.basename} from #{name}"
      end

      SecondaryActiveRecord::Migration.copy(SecondaryActiveRecord::Tasks::DatabaseTasks.migrations_paths.first, railties,
                                    on_skip: on_skip, on_copy: on_copy)
    end
  end
end
