# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/book"

class EnumTest < SecondaryActiveRecord::TestCase
  fixtures :books, :authors, :author_addresses

  setup do
    @book = books(:awdr)
  end

  test "query state by predicate" do
    assert_predicate @book, :published?
    assert_not_predicate @book, :written?
    assert_not_predicate @book, :proposed?

    assert_predicate @book, :read?
    assert_predicate @book, :in_english?
    assert_predicate @book, :author_visibility_visible?
    assert_predicate @book, :illustrator_visibility_visible?
    assert_predicate @book, :with_medium_font_size?
    assert_predicate @book, :medium_to_read?
  end

  test "query state with strings" do
    assert_equal "published", @book.status
    assert_equal "read", @book.read_status
    assert_equal "english", @book.language
    assert_equal "visible", @book.author_visibility
    assert_equal "visible", @book.illustrator_visibility
    assert_equal "medium", @book.difficulty
  end

  test "find via scope" do
    assert_equal @book, Book.published.first
    assert_equal @book, Book.read.first
    assert_equal @book, Book.in_english.first
    assert_equal @book, Book.author_visibility_visible.first
    assert_equal @book, Book.illustrator_visibility_visible.first
    assert_equal @book, Book.medium_to_read.first
    assert_equal books(:ddd), Book.forgotten.first
    assert_equal books(:rfr), authors(:david).unpublished_books.first
  end

  test "find via where with values" do
    published, written = Book.statuses[:published], Book.statuses[:written]

    assert_equal @book, Book.where(status: published).first
    assert_not_equal @book, Book.where(status: written).first
    assert_equal @book, Book.where(status: [published]).first
    assert_not_equal @book, Book.where(status: [written]).first
    assert_not_equal @book, Book.where("status <> ?", published).first
    assert_equal @book, Book.where("status <> ?", written).first
  end

  test "find via where with symbols" do
    assert_equal @book, Book.where(status: :published).first
    assert_not_equal @book, Book.where(status: :written).first
    assert_equal @book, Book.where(status: [:published]).first
    assert_not_equal @book, Book.where(status: [:written]).first
    assert_not_equal @book, Book.where.not(status: :published).first
    assert_equal @book, Book.where.not(status: :written).first
    assert_equal books(:ddd), Book.where(read_status: :forgotten).first
  end

  test "find via where with strings" do
    assert_equal @book, Book.where(status: "published").first
    assert_not_equal @book, Book.where(status: "written").first
    assert_equal @book, Book.where(status: ["published"]).first
    assert_not_equal @book, Book.where(status: ["written"]).first
    assert_not_equal @book, Book.where.not(status: "published").first
    assert_equal @book, Book.where.not(status: "written").first
    assert_equal books(:ddd), Book.where(read_status: "forgotten").first
  end

  test "build from scope" do
    assert_predicate Book.written.build, :written?
    assert_not_predicate Book.written.build, :proposed?
  end

  test "build from where" do
    assert_predicate Book.where(status: Book.statuses[:written]).build, :written?
    assert_not_predicate Book.where(status: Book.statuses[:written]).build, :proposed?
    assert_predicate Book.where(status: :written).build, :written?
    assert_not_predicate Book.where(status: :written).build, :proposed?
    assert_predicate Book.where(status: "written").build, :written?
    assert_not_predicate Book.where(status: "written").build, :proposed?
  end

  test "update by declaration" do
    @book.written!
    assert_predicate @book, :written?
    @book.in_english!
    assert_predicate @book, :in_english?
    @book.author_visibility_visible!
    assert_predicate @book, :author_visibility_visible?
  end

  test "update by setter" do
    @book.update! status: :written
    assert_predicate @book, :written?
  end

  test "enum methods are overwritable" do
    assert_equal "do publish work...", @book.published!
    assert_predicate @book, :published?
  end

  test "direct assignment" do
    @book.status = :written
    assert_predicate @book, :written?
  end

  test "assign string value" do
    @book.status = "written"
    assert_predicate @book, :written?
  end

  test "enum changed attributes" do
    old_status = @book.status
    old_language = @book.language
    @book.status = :proposed
    @book.language = :spanish
    assert_equal old_status, @book.changed_attributes[:status]
    assert_equal old_language, @book.changed_attributes[:language]
  end

  test "enum changes" do
    old_status = @book.status
    old_language = @book.language
    @book.status = :proposed
    @book.language = :spanish
    assert_equal [old_status, "proposed"], @book.changes[:status]
    assert_equal [old_language, "spanish"], @book.changes[:language]
  end

  test "enum attribute was" do
    old_status = @book.status
    old_language = @book.language
    @book.status = :published
    @book.language = :spanish
    assert_equal old_status, @book.attribute_was(:status)
    assert_equal old_language, @book.attribute_was(:language)
  end

  test "enum attribute changed" do
    @book.status = :proposed
    @book.language = :french
    assert @book.attribute_changed?(:status)
    assert @book.attribute_changed?(:language)
  end

  test "enum attribute changed to" do
    @book.status = :proposed
    @book.language = :french
    assert @book.attribute_changed?(:status, to: "proposed")
    assert @book.attribute_changed?(:language, to: "french")
  end

  test "enum attribute changed from" do
    old_status = @book.status
    old_language = @book.language
    @book.status = :proposed
    @book.language = :french
    assert @book.attribute_changed?(:status, from: old_status)
    assert @book.attribute_changed?(:language, from: old_language)
  end

  test "enum attribute changed from old status to new status" do
    old_status = @book.status
    old_language = @book.language
    @book.status = :proposed
    @book.language = :french
    assert @book.attribute_changed?(:status, from: old_status, to: "proposed")
    assert @book.attribute_changed?(:language, from: old_language, to: "french")
  end

  test "enum didn't change" do
    old_status = @book.status
    @book.status = old_status
    assert_not @book.attribute_changed?(:status)
  end

  test "persist changes that are dirty" do
    @book.status = :proposed
    assert @book.attribute_changed?(:status)
    @book.status = :written
    assert @book.attribute_changed?(:status)
  end

  test "reverted changes that are not dirty" do
    old_status = @book.status
    @book.status = :proposed
    assert @book.attribute_changed?(:status)
    @book.status = old_status
    assert_not @book.attribute_changed?(:status)
  end

  test "reverted changes are not dirty going from nil to value and back" do
    book = Book.create!(nullable_status: nil)

    book.nullable_status = :married
    assert book.attribute_changed?(:nullable_status)

    book.nullable_status = nil
    assert_not book.attribute_changed?(:nullable_status)
  end

  test "assign non existing value raises an error" do
    e = assert_raises(ArgumentError) do
      @book.status = :unknown
    end
    assert_equal "'unknown' is not a valid status", e.message
  end

  test "NULL values from database should be casted to nil" do
    Book.where(id: @book.id).update_all("status = NULL")
    assert_nil @book.reload.status
  end

  test "assign nil value" do
    @book.status = nil
    assert_nil @book.status
  end

  test "assign empty string value" do
    @book.status = ""
    assert_nil @book.status
  end

  test "assign long empty string value" do
    @book.status = "   "
    assert_nil @book.status
  end

  test "constant to access the mapping" do
    assert_equal 0, Book.statuses[:proposed]
    assert_equal 1, Book.statuses["written"]
    assert_equal 2, Book.statuses[:published]
  end

  test "building new objects with enum scopes" do
    assert_predicate Book.written.build, :written?
    assert_predicate Book.read.build, :read?
    assert_predicate Book.in_spanish.build, :in_spanish?
    assert_predicate Book.illustrator_visibility_invisible.build, :illustrator_visibility_invisible?
  end

  test "creating new objects with enum scopes" do
    assert_predicate Book.written.create, :written?
    assert_predicate Book.read.create, :read?
    assert_predicate Book.in_spanish.create, :in_spanish?
    assert_predicate Book.illustrator_visibility_invisible.create, :illustrator_visibility_invisible?
  end

  test "_before_type_cast" do
    assert_equal 2, @book.status_before_type_cast
    assert_equal "published", @book.status

    @book.status = "published"

    assert_equal "published", @book.status_before_type_cast
    assert_equal "published", @book.status
  end

  test "reserved enum names" do
    klass = Class.new(SecondaryActiveRecord::Base) do
      self.table_name = "books"
      enum status: [:proposed, :written, :published]
    end

    conflicts = [
      :column,     # generates class method .columns, which conflicts with an AR method
      :logger,     # generates #logger, which conflicts with an AR method
      :attributes, # generates #attributes=, which conflicts with an AR method
    ]

    conflicts.each_with_index do |name, i|
      e = assert_raises(ArgumentError) do
        klass.class_eval { enum name => ["value_#{i}"] }
      end
      assert_match(/You tried to define an enum named \"#{name}\" on the model/, e.message)
    end
  end

  test "reserved enum values" do
    klass = Class.new(SecondaryActiveRecord::Base) do
      self.table_name = "books"
      enum status: [:proposed, :written, :published]
    end

    conflicts = [
      :new,      # generates a scope that conflicts with an AR class method
      :valid,    # generates #valid?, which conflicts with an AR method
      :save,     # generates #save!, which conflicts with an AR method
      :proposed, # same value as an existing enum
      :public, :private, :protected, # some important methods on Module and Class
      :name, :parent, :superclass
    ]

    conflicts.each_with_index do |value, i|
      e = assert_raises(ArgumentError, "enum value `#{value}` should not be allowed") do
        klass.class_eval { enum "status_#{i}" => [value] }
      end
      assert_match(/You tried to define an enum named .* on the model/, e.message)
    end
  end

  test "reserved enum values for relation" do
    relation_method_samples = [
      :records,
      :to_ary,
      :scope_for_create
    ]

    relation_method_samples.each do |value|
      e = assert_raises(ArgumentError, "enum value `#{value}` should not be allowed") do
        Class.new(SecondaryActiveRecord::Base) do
          self.table_name = "books"
          enum category: [:other, value]
        end
      end
      assert_match(/You tried to define an enum named .* on the model/, e.message)
    end
  end

  test "overriding enum method should not raise" do
    assert_nothing_raised do
      Class.new(SecondaryActiveRecord::Base) do
        self.table_name = "books"

        def published!
          super
          "do publish work..."
        end

        enum status: [:proposed, :written, :published]

        def written!
          super
          "do written work..."
        end
      end
    end
  end

  test "validate uniqueness" do
    klass = Class.new(SecondaryActiveRecord::Base) do
      def self.name; "Book"; end
      enum status: [:proposed, :written]
      validates_uniqueness_of :status
    end
    klass.delete_all
    klass.create!(status: "proposed")
    book = klass.new(status: "written")
    assert_predicate book, :valid?
    book.status = "proposed"
    assert_not_predicate book, :valid?
  end

  test "validate inclusion of value in array" do
    klass = Class.new(SecondaryActiveRecord::Base) do
      def self.name; "Book"; end
      enum status: [:proposed, :written]
      validates_inclusion_of :status, in: ["written"]
    end
    klass.delete_all
    invalid_book = klass.new(status: "proposed")
    assert_not_predicate invalid_book, :valid?
    valid_book = klass.new(status: "written")
    assert_predicate valid_book, :valid?
  end

  test "enums are distinct per class" do
    klass1 = Class.new(SecondaryActiveRecord::Base) do
      self.table_name = "books"
      enum status: [:proposed, :written]
    end

    klass2 = Class.new(SecondaryActiveRecord::Base) do
      self.table_name = "books"
      enum status: [:drafted, :uploaded]
    end

    book1 = klass1.proposed.create!
    book1.status = :written
    assert_equal ["proposed", "written"], book1.status_change

    book2 = klass2.drafted.create!
    book2.status = :uploaded
    assert_equal ["drafted", "uploaded"], book2.status_change
  end

  test "enums are inheritable" do
    subklass1 = Class.new(Book)

    subklass2 = Class.new(Book) do
      enum status: [:drafted, :uploaded]
    end

    book1 = subklass1.proposed.create!
    book1.status = :written
    assert_equal ["proposed", "written"], book1.status_change

    book2 = subklass2.drafted.create!
    book2.status = :uploaded
    assert_equal ["drafted", "uploaded"], book2.status_change
  end

  test "declare multiple enums at a time" do
    klass = Class.new(SecondaryActiveRecord::Base) do
      self.table_name = "books"
      enum status: [:proposed, :written, :published],
           nullable_status: [:single, :married]
    end

    book1 = klass.proposed.create!
    assert_predicate book1, :proposed?

    book2 = klass.single.create!
    assert_predicate book2, :single?
  end

  test "enum with alias_attribute" do
    klass = Class.new(SecondaryActiveRecord::Base) do
      self.table_name = "books"
      alias_attribute :aliased_status, :status
      enum aliased_status: [:proposed, :written, :published]
    end

    book = klass.proposed.create!
    assert_predicate book, :proposed?
    assert_equal "proposed", book.aliased_status

    book = klass.find(book.id)
    assert_predicate book, :proposed?
    assert_equal "proposed", book.aliased_status
  end

  test "query state by predicate with prefix" do
    assert_predicate @book, :author_visibility_visible?
    assert_not_predicate @book, :author_visibility_invisible?
    assert_predicate @book, :illustrator_visibility_visible?
    assert_not_predicate @book, :illustrator_visibility_invisible?
  end

  test "query state by predicate with custom prefix" do
    assert_predicate @book, :in_english?
    assert_not_predicate @book, :in_spanish?
    assert_not_predicate @book, :in_french?
  end

  test "query state by predicate with custom suffix" do
    assert_predicate @book, :medium_to_read?
    assert_not_predicate @book, :easy_to_read?
    assert_not_predicate @book, :hard_to_read?
  end

  test "enum methods with custom suffix defined" do
    assert_respond_to @book.class, :easy_to_read
    assert_respond_to @book.class, :medium_to_read
    assert_respond_to @book.class, :hard_to_read

    assert_respond_to @book, :easy_to_read?
    assert_respond_to @book, :medium_to_read?
    assert_respond_to @book, :hard_to_read?

    assert_respond_to @book, :easy_to_read!
    assert_respond_to @book, :medium_to_read!
    assert_respond_to @book, :hard_to_read!
  end

  test "update enum attributes with custom suffix" do
    @book.medium_to_read!
    assert_not_predicate @book, :easy_to_read?
    assert_predicate @book, :medium_to_read?
    assert_not_predicate @book, :hard_to_read?

    @book.easy_to_read!
    assert_predicate @book, :easy_to_read?
    assert_not_predicate @book, :medium_to_read?
    assert_not_predicate @book, :hard_to_read?

    @book.hard_to_read!
    assert_not_predicate @book, :easy_to_read?
    assert_not_predicate @book, :medium_to_read?
    assert_predicate @book, :hard_to_read?
  end

  test "uses default status when no status is provided in fixtures" do
    book = books(:tlg)
    assert book.proposed?, "expected fixture to default to proposed status"
    assert book.in_english?, "expected fixture to default to english language"
  end

  test "uses default value from database on initialization" do
    book = Book.new
    assert_predicate book, :proposed?
  end

  test "uses default value from database on initialization when using custom mapping" do
    book = Book.new
    assert_predicate book, :hard?
  end

  test "data type of Enum type" do
    assert_equal :integer, Book.type_for_attribute("status").type
  end
end
