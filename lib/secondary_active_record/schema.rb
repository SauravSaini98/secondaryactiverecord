# frozen_string_literal: true

module SecondaryActiveRecord
  # = Secondary Active Record \Schema
  #
  # Allows programmers to programmatically define a schema in a portable
  # DSL. This means you can define tables, indexes, etc. without using SQL
  # directly, so your applications can more easily support multiple
  # databases.
  #
  # Usage:
  #
  #   SecondaryActiveRecord::Schema.define do
  #     create_table :authors do |t|
  #       t.string :name, null: false
  #     end
  #
  #     add_index :authors, :name, :unique
  #
  #     create_table :posts do |t|
  #       t.integer :author_id, null: false
  #       t.string :subject
  #       t.text :body
  #       t.boolean :private, default: false
  #     end
  #
  #     add_index :posts, :author_id
  #   end
  #
  # SecondaryActiveRecord::Schema is only supported by database adapters that also
  # support migrations, the two features being very similar.
  class Schema < Migration::Current
    # Eval the given block. All methods available to the current connection
    # adapter are available within the block, so you can easily use the
    # database definition DSL to build up your schema (
    # {create_table}[rdoc-ref:ConnectionAdapters::SchemaStatements#create_table],
    # {add_index}[rdoc-ref:ConnectionAdapters::SchemaStatements#add_index], etc.).
    #
    # The +info+ hash is optional, and if given is used to define metadata
    # about the current schema (currently, only the schema's version):
    #
    #   SecondaryActiveRecord::Schema.define(version: 2038_01_19_000001) do
    #     ...
    #   end
    def self.define(info = {}, &block)
      new.define(info, &block)
    end

    def define(info, &block) # :nodoc:
      instance_eval(&block)

      if info[:version].present?
        SecondaryActiveRecord::SchemaMigration.create_table
        connection.assume_migrated_upto_version(info[:version], migrations_paths)
      end

      SecondaryActiveRecord::InternalMetadata.create_table
      SecondaryActiveRecord::InternalMetadata[:environment] = connection.migration_context.current_environment
    end

    private
      # Returns the migrations paths.
      #
      #   SecondaryActiveRecord::Schema.new.migrations_paths
      #   # => ["sec_db/migrate"] # Rails migration path by default.
      def migrations_paths
        SecondaryActiveRecord::Migrator.migrations_paths
      end
  end
end