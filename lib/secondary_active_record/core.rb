# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/string/filters"
require "concurrent/map"

module SecondaryActiveRecord
  module Core
    extend ActiveSupport::Concern

    included do
      ##
      # :singleton-method:
      #
      # Accepts a logger conforming to the interface of Log4r which is then
      # passed on to any new database connections made and which can be
      # retrieved on both a class and instance level by calling +logger+.
      mattr_accessor :logger, instance_writer: false

      ##
      # :singleton-method:
      #
      # Specifies if the methods calling database queries should be logged below
      # their relevant queries. Defaults to false.
      mattr_accessor :verbose_query_logs, instance_writer: false, default: false

      ##
      # Contains the database configuration - as is typically stored in config/secondary_database.yml -
      # as a Hash.
      #
      # For example, the following secondary_database.yml...
      #
      #   development:
      #     adapter: sqlite3
      #     database: sec_db/development.sqlite3
      #
      #   production:
      #     adapter: sqlite3
      #     database: sec_db/production.sqlite3
      #
      # ...would result in SecondaryActiveRecord::Base.configurations to look like this:
      #
      #   {
      #      'development' => {
      #         'adapter'  => 'sqlite3',
      #         'database' => 'sec_db/development.sqlite3'
      #      },
      #      'production' => {
      #         'adapter'  => 'sqlite3',
      #         'database' => 'sec_db/production.sqlite3'
      #      }
      #   }
      def self.configurations=(config)
        @@configurations = SecondaryActiveRecord::ConnectionHandling::MergeAndResolveDefaultUrlConfig.new(config).resolve
      end
      self.configurations = {}

      # Returns fully resolved configurations hash
      def self.configurations
        @@configurations
      end

      ##
      # :singleton-method:
      # Determines whether to use Time.utc (using :utc) or Time.local (using :local) when pulling
      # dates and times from the database. This is set to :utc by default.
      mattr_accessor :default_timezone, instance_writer: false, default: :utc

      ##
      # :singleton-method:
      # Specifies the format to use when dumping the database schema with Rails'
      # Rakefile. If :sql, the schema is dumped as (potentially database-
      # specific) SQL statements. If :ruby, the schema is dumped as an
      # SecondaryActiveRecord::Schema file which can be loaded into any database that
      # supports migrations. Use :ruby if you want to have different database
      # adapters for, e.g., your development and test environments.
      mattr_accessor :schema_format, instance_writer: false, default: :ruby

      ##
      # :singleton-method:
      # Specifies if an error should be raised if the query has an order being
      # ignored when doing batch queries. Useful in applications where the
      # scope being ignored is error-worthy, rather than a warning.
      mattr_accessor :error_on_ignored_order, instance_writer: false, default: false

      # :singleton-method:
      # Specify the behavior for unsafe raw query methods. Values are as follows
      #   deprecated - Warnings are logged when unsafe raw SQL is passed to
      #                query methods.
      #   disabled   - Unsafe raw SQL passed to query methods results in
      #                UnknownAttributeReference exception.
      mattr_accessor :allow_unsafe_raw_sql, instance_writer: false, default: :deprecated

      ##
      # :singleton-method:
      # Specify whether or not to use timestamps for migration versions
      mattr_accessor :timestamped_migrations, instance_writer: false, default: true

      ##
      # :singleton-method:
      # Specify whether schema dump should happen at the end of the
      # sec_db:migrate rake task. This is true by default, which is useful for the
      # development environment. This should ideally be false in the production
      # environment where dumping schema is rarely needed.
      mattr_accessor :dump_schema_after_migration, instance_writer: false, default: true

      ##
      # :singleton-method:
      # Specifies which database schemas to dump when calling sec_db:structure:dump.
      # If the value is :schema_search_path (the default), any schemas listed in
      # schema_search_path are dumped. Use :all to dump all schemas regardless
      # of schema_search_path, or a string of comma separated schemas for a
      # custom list.
      mattr_accessor :dump_schemas, instance_writer: false, default: :schema_search_path

      ##
      # :singleton-method:
      # Specify a threshold for the size of query result sets. If the number of
      # records in the set exceeds the threshold, a warning is logged. This can
      # be used to identify queries which load thousands of records and
      # potentially cause memory bloat.
      mattr_accessor :warn_on_records_fetched_greater_than, instance_writer: false

      mattr_accessor :maintain_test_schema, instance_accessor: false

      mattr_accessor :belongs_to_required_by_default, instance_accessor: false

      class_attribute :default_connection_handler, instance_writer: false

      def self.connection_handler
        SecondaryActiveRecord::RuntimeRegistry.connection_handler || default_connection_handler
      end

      def self.connection_handler=(handler)
        SecondaryActiveRecord::RuntimeRegistry.connection_handler = handler
      end

      self.default_connection_handler = ConnectionAdapters::ConnectionHandler.new
    end

    module ClassMethods # :nodoc:
      def allocate
        define_attribute_methods
        super
      end

      def initialize_find_by_cache # :nodoc:
        @find_by_statement_cache = { true => Concurrent::Map.new, false => Concurrent::Map.new }
      end

      def inherited(child_class) # :nodoc:
        # initialize cache at class definition for thread safety
        child_class.initialize_find_by_cache
        super
      end

      def find(*ids) # :nodoc:
        # We don't have cache keys for this stuff yet
        return super unless ids.length == 1
        return super if block_given? ||
                        primary_key.nil? ||
                        scope_attributes? ||
                        columns_hash.include?(inheritance_column)

        id = ids.first

        return super if StatementCache.unsupported_value?(id)

        key = primary_key

        statement = cached_find_by_statement(key) { |params|
          where(key => params.bind).limit(1)
        }

        record = statement.execute([id], connection).first
        unless record
          raise RecordNotFound.new("Couldn't find #{name} with '#{primary_key}'=#{id}",
                                   name, primary_key, id)
        end
        record
      rescue ::RangeError
        raise RecordNotFound.new("Couldn't find #{name} with an out of range value for '#{primary_key}'",
                                 name, primary_key)
      end

      def find_by(*args) # :nodoc:
        return super if scope_attributes? || reflect_on_all_aggregations.any?

        hash = args.first

        return super if !(Hash === hash) || hash.values.any? { |v|
          StatementCache.unsupported_value?(v)
        }

        # We can't cache Post.find_by(author: david) ...yet
        return super unless hash.keys.all? { |k| columns_hash.has_key?(k.to_s) }

        keys = hash.keys

        statement = cached_find_by_statement(keys) { |params|
          wheres = keys.each_with_object({}) { |param, o|
            o[param] = params.bind
          }
          where(wheres).limit(1)
        }
        begin
          statement.execute(hash.values, connection).first
        rescue TypeError
          raise SecondaryActiveRecord::StatementInvalid
        rescue ::RangeError
          nil
        end
      end

      def find_by!(*args) # :nodoc:
        find_by(*args) || raise(RecordNotFound.new("Couldn't find #{name}", name))
      end

      def initialize_generated_modules # :nodoc:
        generated_association_methods
      end

      def generated_association_methods
        @generated_association_methods ||= begin
          mod = const_set(:GeneratedAssociationMethods, Module.new)
          private_constant :GeneratedAssociationMethods
          include mod

          mod
        end
      end

      # Returns a string like 'Post(id:integer, title:string, body:text)'
      def inspect
        if self == Base
          super
        elsif abstract_class?
          "#{super}(abstract)"
        elsif !connected?
          "#{super} (call '#{super}.connection' to establish a connection)"
        elsif table_exists?
          attr_list = attribute_types.map { |name, type| "#{name}: #{type.type}" } * ", "
          "#{super}(#{attr_list})"
        else
          "#{super}(Table doesn't exist)"
        end
      end

      # Overwrite the default class equality method to provide support for decorated models.
      def ===(object)
        object.is_a?(self)
      end

      # Returns an instance of <tt>Arel::Table</tt> loaded with the current table name.
      #
      #   class Post < SecondaryActiveRecord::Base
      #     scope :published_and_commented, -> { published.and(arel_table[:comments_count].gt(0)) }
      #   end
      def arel_table # :nodoc:
        @arel_table ||= Arel::Table.new(table_name, type_caster: type_caster)
      end

      def arel_attribute(name, table = arel_table) # :nodoc:
        name = attribute_alias(name) if attribute_alias?(name)
        table[name]
      end

      def predicate_builder # :nodoc:
        @predicate_builder ||= PredicateBuilder.new(table_metadata)
      end

      def type_caster # :nodoc:
        TypeCaster::Map.new(self)
      end

      private

        def cached_find_by_statement(key, &block)
          cache = @find_by_statement_cache[connection.prepared_statements]
          cache.compute_if_absent(key) { StatementCache.create(connection, &block) }
        end

        def relation
          relation = Relation.create(self)

          if finder_needs_type_condition? && !ignore_default_scope?
            relation.where!(type_condition)
            relation.create_with!(inheritance_column.to_s => sti_name)
          else
            relation
          end
        end

        def table_metadata
          TableMetadata.new(self, arel_table)
        end
    end

    # New objects can be instantiated as either empty (pass no construction parameter) or pre-set with
    # attributes but not yet saved (pass a hash with key names matching the associated table column names).
    # In both instances, valid attribute keys are determined by the column names of the associated table --
    # hence you can't have attributes that aren't part of the table columns.
    #
    # ==== Example:
    #   # Instantiates a single new object
    #   User.new(first_name: 'Jamie')
    def initialize(attributes = nil)
      self.class.define_attribute_methods
      @attributes = self.class._default_attributes.deep_dup

      init_internals
      initialize_internals_callback

      assign_attributes(attributes) if attributes

      yield self if block_given?
      _run_initialize_callbacks
    end

    # Initialize an empty model object from +coder+. +coder+ should be
    # the result of previously encoding an Secondary Active Record model, using
    # #encode_with.
    #
    #   class Post < SecondaryActiveRecord::Base
    #   end
    #
    #   old_post = Post.new(title: "hello world")
    #   coder = {}
    #   old_post.encode_with(coder)
    #
    #   post = Post.allocate
    #   post.init_with(coder)
    #   post.title # => 'hello world'
    def init_with(coder)
      coder = LegacyYamlAdapter.convert(self.class, coder)
      @attributes = self.class.yaml_encoder.decode(coder)

      init_internals

      @new_record = coder["new_record"]

      self.class.define_attribute_methods

      yield self if block_given?

      _run_find_callbacks
      _run_initialize_callbacks

      self
    end

    ##
    # :method: clone
    # Identical to Ruby's clone method.  This is a "shallow" copy.  Be warned that your attributes are not copied.
    # That means that modifying attributes of the clone will modify the original, since they will both point to the
    # same attributes hash. If you need a copy of your attributes hash, please use the #dup method.
    #
    #   user = User.first
    #   new_user = user.clone
    #   user.name               # => "Bob"
    #   new_user.name = "Joe"
    #   user.name               # => "Joe"
    #
    #   user.object_id == new_user.object_id            # => false
    #   user.name.object_id == new_user.name.object_id  # => true
    #
    #   user.name.object_id == user.dup.name.object_id  # => false

    ##
    # :method: dup
    # Duped objects have no id assigned and are treated as new records. Note
    # that this is a "shallow" copy as it copies the object's attributes
    # only, not its associations. The extent of a "deep" copy is application
    # specific and is therefore left to the application to implement according
    # to its need.
    # The dup method does not preserve the timestamps (created|updated)_(at|on).

    ##
    def initialize_dup(other) # :nodoc:
      @attributes = @attributes.deep_dup
      @attributes.reset(self.class.primary_key)

      _run_initialize_callbacks

      @new_record               = true
      @destroyed                = false
      @_start_transaction_state = {}
      @transaction_state        = nil

      super
    end

    # Populate +coder+ with attributes about this record that should be
    # serialized. The structure of +coder+ defined in this method is
    # guaranteed to match the structure of +coder+ passed to the #init_with
    # method.
    #
    # Example:
    #
    #   class Post < SecondaryActiveRecord::Base
    #   end
    #   coder = {}
    #   Post.new.encode_with(coder)
    #   coder # => {"attributes" => {"id" => nil, ... }}
    def encode_with(coder)
      self.class.yaml_encoder.encode(@attributes, coder)
      coder["new_record"] = new_record?
      coder["active_record_yaml_version"] = 2
    end

    # Returns true if +comparison_object+ is the same exact object, or +comparison_object+
    # is of the same type and +self+ has an ID and it is equal to +comparison_object.id+.
    #
    # Note that new records are different from any other record by definition, unless the
    # other record is the receiver itself. Besides, if you fetch existing records with
    # +select+ and leave the ID out, you're on your own, this predicate will return false.
    #
    # Note also that destroying a record preserves its ID in the model instance, so deleted
    # models are still comparable.
    def ==(comparison_object)
      super ||
        comparison_object.instance_of?(self.class) &&
        !id.nil? &&
        comparison_object.id == id
    end
    alias :eql? :==

    # Delegates to id in order to allow two records of the same type and id to work with something like:
    #   [ Person.find(1), Person.find(2), Person.find(3) ] & [ Person.find(1), Person.find(4) ] # => [ Person.find(1) ]
    def hash
      if id
        self.class.hash ^ id.hash
      else
        super
      end
    end

    # Clone and freeze the attributes hash such that associations are still
    # accessible, even on destroyed records, but cloned models will not be
    # frozen.
    def freeze
      @attributes = @attributes.clone.freeze
      self
    end

    # Returns +true+ if the attributes hash has been frozen.
    def frozen?
      @attributes.frozen?
    end

    # Allows sort on objects
    def <=>(other_object)
      if other_object.is_a?(self.class)
        to_key <=> other_object.to_key
      else
        super
      end
    end

    # Returns +true+ if the record is read only. Records loaded through joins with piggy-back
    # attributes will be marked as read only since they cannot be saved.
    def readonly?
      @readonly
    end

    # Marks this record as read only.
    def readonly!
      @readonly = true
    end

    def connection_handler
      self.class.connection_handler
    end

    # Returns the contents of the record as a nicely formatted string.
    def inspect
      # We check defined?(@attributes) not to issue warnings if the object is
      # allocated but not initialized.
      inspection = if defined?(@attributes) && @attributes
        self.class.attribute_names.collect do |name|
          if has_attribute?(name)
            "#{name}: #{attribute_for_inspect(name)}"
          end
        end.compact.join(", ")
      else
        "not initialized"
      end

      "#<#{self.class} #{inspection}>"
    end

    # Takes a PP and prettily prints this record to it, allowing you to get a nice result from <tt>pp record</tt>
    # when pp is required.
    def pretty_print(pp)
      return super if custom_inspect_method_defined?
      pp.object_address_group(self) do
        if defined?(@attributes) && @attributes
          column_names = self.class.column_names.select { |name| has_attribute?(name) || new_record? }
          pp.seplist(column_names, proc { pp.text "," }) do |column_name|
            column_value = read_attribute(column_name)
            pp.breakable " "
            pp.group(1) do
              pp.text column_name
              pp.text ":"
              pp.breakable
              pp.pp column_value
            end
          end
        else
          pp.breakable " "
          pp.text "not initialized"
        end
      end
    end

    # Returns a hash of the given methods with their names as keys and returned values as values.
    def slice(*methods)
      Hash[methods.flatten.map! { |method| [method, public_send(method)] }].with_indifferent_access
    end

    private

      # +Array#flatten+ will call +#to_ary+ (recursively) on each of the elements of
      # the array, and then rescues from the possible +NoMethodError+. If those elements are
      # +SecondaryActiveRecord::Base+'s, then this triggers the various +method_missing+'s that we have,
      # which significantly impacts upon performance.
      #
      # So we can avoid the +method_missing+ hit by explicitly defining +#to_ary+ as +nil+ here.
      #
      # See also https://tenderlovemaking.com/2011/06/28/til-its-ok-to-return-nil-from-to_ary.html
      def to_ary
        nil
      end

      def init_internals
        @readonly                 = false
        @destroyed                = false
        @marked_for_destruction   = false
        @destroyed_by_association = nil
        @new_record               = true
        @_start_transaction_state = {}
        @transaction_state        = nil
      end

      def initialize_internals_callback
      end

      def thaw
        if frozen?
          @attributes = @attributes.dup
        end
      end

      def custom_inspect_method_defined?
        self.class.instance_method(:inspect).owner != SecondaryActiveRecord::Base.instance_method(:inspect).owner
      end
  end
end
