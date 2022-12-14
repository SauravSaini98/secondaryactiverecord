# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class SQLite3CollationTest < SecondaryActiveRecord::SQLite3TestCase
  include SchemaDumpingHelper

  def setup
    @connection = SecondaryActiveRecord::Base.connection
    @connection.create_table :collation_table_sqlite3, force: true do |t|
      t.string :string_nocase, collation: "NOCASE"
      t.text :text_rtrim, collation: "RTRIM"
    end
  end

  def teardown
    @connection.drop_table :collation_table_sqlite3, if_exists: true
  end

  test "string column with collation" do
    column = @connection.columns(:collation_table_sqlite3).find { |c| c.name == "string_nocase" }
    assert_equal :string, column.type
    assert_equal "NOCASE", column.collation
  end

  test "text column with collation" do
    column = @connection.columns(:collation_table_sqlite3).find { |c| c.name == "text_rtrim" }
    assert_equal :text, column.type
    assert_equal "RTRIM", column.collation
  end

  test "add column with collation" do
    @connection.add_column :collation_table_sqlite3, :title, :string, collation: "RTRIM"

    column = @connection.columns(:collation_table_sqlite3).find { |c| c.name == "title" }
    assert_equal :string, column.type
    assert_equal "RTRIM", column.collation
  end

  test "change column with collation" do
    @connection.add_column :collation_table_sqlite3, :description, :string
    @connection.change_column :collation_table_sqlite3, :description, :text, collation: "RTRIM"

    column = @connection.columns(:collation_table_sqlite3).find { |c| c.name == "description" }
    assert_equal :text, column.type
    assert_equal "RTRIM", column.collation
  end

  test "schema dump includes collation" do
    output = dump_table_schema("collation_table_sqlite3")
    assert_match %r{t\.string\s+"string_nocase",\s+collation: "NOCASE"$}, output
    assert_match %r{t\.text\s+"text_rtrim",\s+collation: "RTRIM"$}, output
  end
end
