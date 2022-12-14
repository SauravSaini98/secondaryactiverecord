# frozen_string_literal: true

require "secondary_active_record"
require "rails"
require "active_model/railtie"

# For now, action_controller must always be present with
# Rails, so let's make sure that it gets required before
# here. This is needed for correctly setting up the middleware.
# In the future, this might become an optional require.
require "action_controller/railtie"

module SecondaryActiveRecord
  # = Secondary Active Record Railtie
  class Railtie < Rails::Railtie # :nodoc:
    config.secondary_active_record = ActiveSupport::OrderedOptions.new

    config.app_generators.orm :secondary_active_record, migration: true,
                                              timestamps: true

    config.action_dispatch.rescue_responses.merge!(
      "SecondaryActiveRecord::RecordNotFound"   => :not_found,
      "SecondaryActiveRecord::StaleObjectError" => :conflict,
      "SecondaryActiveRecord::RecordInvalid"    => :unprocessable_entity,
      "SecondaryActiveRecord::RecordNotSaved"   => :unprocessable_entity
    )

    config.secondary_active_record.use_schema_cache_dump = true
    config.secondary_active_record.maintain_test_schema = true

    config.secondary_active_record.sqlite3 = ActiveSupport::OrderedOptions.new
    config.secondary_active_record.sqlite3.represent_boolean_as_integer = nil

    config.eager_load_namespaces << SecondaryActiveRecord

    rake_tasks do
      namespace :db do
        task :load_config do
          SecondaryActiveRecord::Tasks::DatabaseTasks.database_configuration = Rails.application.config.database_configuration

          if defined?(ENGINE_ROOT) && engine = Rails::Engine.find(ENGINE_ROOT)
            if engine.paths["db/migrate"].existent
              SecondaryActiveRecord::Tasks::DatabaseTasks.migrations_paths += engine.paths["db/migrate"].to_a
            end
          end
        end
      end

      load "secondary_active_record/railties/databases.rake"
    end

    # When loading console, force SecondaryActiveRecord::Base to be loaded
    # to avoid cross references when loading a constant for the
    # first time. Also, make it output to STDERR.
    console do |app|
      require "secondary_active_record/railties/console_sandbox" if app.sandbox?
      require "secondary_active_record/base"
      unless ActiveSupport::Logger.logger_outputs_to?(Rails.logger, STDERR, STDOUT)
        console = ActiveSupport::Logger.new(STDERR)
        Rails.logger.extend ActiveSupport::Logger.broadcast console
      end
      SecondaryActiveRecord::Base.verbose_query_logs = false
    end

    runner do
      require "secondary_active_record/base"
    end

    initializer "secondary_active_record.initialize_timezone" do
      ActiveSupport.on_load(:secondary_active_record) do
        self.time_zone_aware_attributes = true
        self.default_timezone = :utc
      end
    end

    initializer "secondary_active_record.logger" do
      ActiveSupport.on_load(:secondary_active_record) { self.logger ||= ::Rails.logger }
    end

    initializer "secondary_active_record.migration_error" do
      if config.secondary_active_record.delete(:migration_error) == :page_load
        config.app_middleware.insert_after ::ActionDispatch::Callbacks,
          SecondaryActiveRecord::Migration::CheckPending
      end
    end

    initializer "secondary_active_record.check_schema_cache_dump" do
      if config.secondary_active_record.delete(:use_schema_cache_dump)
        config.after_initialize do |app|
          ActiveSupport.on_load(:secondary_active_record) do
            filename = File.join(app.config.paths["db"].first, "schema_cache.yml")

            if File.file?(filename)
              current_version = SecondaryActiveRecord::Migrator.current_version

              next if current_version.nil?

              cache = YAML.load(File.read(filename))
              if cache.version == current_version
                connection.schema_cache = cache
                connection_pool.schema_cache = cache.dup
              else
                warn "Ignoring db/schema_cache.yml because it has expired. The current schema version is #{current_version}, but the one in the cache is #{cache.version}."
              end
            end
          end
        end
      end
    end

    initializer "secondary_active_record.warn_on_records_fetched_greater_than" do
      if config.secondary_active_record.warn_on_records_fetched_greater_than
        ActiveSupport.on_load(:secondary_active_record) do
          require "secondary_active_record/relation/record_fetch_warning"
        end
      end
    end

    initializer "secondary_active_record.set_configs" do |app|
      ActiveSupport.on_load(:secondary_active_record) do
        configs = app.config.secondary_active_record.dup
        configs.delete(:sqlite3)
        configs.each do |k, v|
          send "#{k}=", v
        end
      end
    end

    # This sets the database configuration from Configuration#database_configuration
    # and then establishes the connection.
    initializer "secondary_active_record.initialize_database" do
      ActiveSupport.on_load(:secondary_active_record) do
        self.configurations = Rails.application.config.database_configuration

        begin
          establish_connection
        rescue SecondaryActiveRecord::NoDatabaseError
          warn <<-end_warning
Oops - You have a database configured, but it doesn't exist yet!

Here's how to get started:

  1. Configure your database in config/secondary_database.yml.
  2. Run `bin/rails db:create` to create the database.
  3. Run `bin/rails db:setup` to load your database schema.
end_warning
          raise
        end
      end
    end

    # Expose database runtime to controller for logging.
    initializer "secondary_active_record.log_runtime" do
      require "secondary_active_record/railties/controller_runtime"
      ActiveSupport.on_load(:action_controller) do
        include SecondaryActiveRecord::Railties::ControllerRuntime
      end
    end

    initializer "secondary_active_record.set_reloader_hooks" do
      ActiveSupport.on_load(:secondary_active_record) do
        ActiveSupport::Reloader.before_class_unload do
          if SecondaryActiveRecord::Base.connected?
            SecondaryActiveRecord::Base.clear_cache!
            SecondaryActiveRecord::Base.clear_reloadable_connections!
          end
        end
      end
    end

    initializer "secondary_active_record.set_executor_hooks" do
      ActiveSupport.on_load(:secondary_active_record) do
        SecondaryActiveRecord::QueryCache.install_executor_hooks
      end
    end

    initializer "secondary_active_record.add_watchable_files" do |app|
      path = app.paths["db"].first
      config.watchable_files.concat ["#{path}/schema.rb", "#{path}/structure.sql"]
    end

    initializer "secondary_active_record.clear_active_connections" do
      config.after_initialize do
        ActiveSupport.on_load(:secondary_active_record) do
          # Ideally the application doesn't connect to the database during boot,
          # but sometimes it does. In case it did, we want to empty out the
          # connection pools so that a non-database-using process (e.g. a master
          # process in a forking server model) doesn't retain a needless
          # connection. If it was needed, the incremental cost of reestablishing
          # this connection is trivial: the rest of the pool would need to be
          # populated anyway.

          clear_active_connections!
          flush_idle_connections!
        end
      end
    end

    initializer "secondary_active_record.check_represent_sqlite3_boolean_as_integer" do
      config.after_initialize do
        ActiveSupport.on_load(:active_record_sqlite3adapter) do
          represent_boolean_as_integer = Rails.application.config.secondary_active_record.sqlite3.delete(:represent_boolean_as_integer)
          unless represent_boolean_as_integer.nil?
            SecondaryActiveRecord::ConnectionAdapters::SQLite3Adapter.represent_boolean_as_integer = represent_boolean_as_integer
          end

          unless SecondaryActiveRecord::ConnectionAdapters::SQLite3Adapter.represent_boolean_as_integer
            ActiveSupport::Deprecation.warn <<-MSG
Leaving `SecondaryActiveRecord::ConnectionAdapters::SQLite3Adapter.represent_boolean_as_integer`
set to false is deprecated. SQLite databases have used 't' and 'f' to serialize
boolean values and must have old data converted to 1 and 0 (its native boolean
serialization) before setting this flag to true. Conversion can be accomplished
by setting up a rake task which runs

  ExampleModel.where("boolean_column = 't'").update_all(boolean_column: 1)
  ExampleModel.where("boolean_column = 'f'").update_all(boolean_column: 0)

for all models and all boolean columns, after which the flag must be set to
true by adding the following to your application.rb file:

  Rails.application.config.secondary_active_record.sqlite3.represent_boolean_as_integer = true
MSG
          end
        end
      end
    end
  end
end
