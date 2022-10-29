# frozen_string_literal: true

module SchemaDumpingHelper
  def dump_table_schema(table, connection = SecondaryActiveRecord::Base.connection)
    old_ignore_tables = SecondaryActiveRecord::SchemaDumper.ignore_tables
    SecondaryActiveRecord::SchemaDumper.ignore_tables = connection.data_sources - [table]
    stream = StringIO.new
    SecondaryActiveRecord::SchemaDumper.dump(SecondaryActiveRecord::Base.connection, stream)
    stream.string
  ensure
    SecondaryActiveRecord::SchemaDumper.ignore_tables = old_ignore_tables
  end

  def dump_all_table_schema(ignore_tables)
    old_ignore_tables, SecondaryActiveRecord::SchemaDumper.ignore_tables = SecondaryActiveRecord::SchemaDumper.ignore_tables, ignore_tables
    stream = StringIO.new
    SecondaryActiveRecord::SchemaDumper.dump(SecondaryActiveRecord::Base.connection, stream)
    stream.string
  ensure
    SecondaryActiveRecord::SchemaDumper.ignore_tables = old_ignore_tables
  end
end
