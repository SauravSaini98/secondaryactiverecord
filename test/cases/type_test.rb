# frozen_string_literal: true

require "cases/helper"

class TypeTest < SecondaryActiveRecord::TestCase
  setup do
    @old_registry = SecondaryActiveRecord::Type.registry
    SecondaryActiveRecord::Type.registry = SecondaryActiveRecord::Type::AdapterSpecificRegistry.new
  end

  teardown do
    SecondaryActiveRecord::Type.registry = @old_registry
  end

  test "registering a new type" do
    type = Struct.new(:args)
    SecondaryActiveRecord::Type.register(:foo, type)

    assert_equal type.new(:arg), SecondaryActiveRecord::Type.lookup(:foo, :arg)
  end

  test "looking up a type for a specific adapter" do
    type = Struct.new(:args)
    pgtype = Struct.new(:args)
    SecondaryActiveRecord::Type.register(:foo, type, override: false)
    SecondaryActiveRecord::Type.register(:foo, pgtype, adapter: :postgresql)

    assert_equal type.new, SecondaryActiveRecord::Type.lookup(:foo, adapter: :sqlite)
    assert_equal pgtype.new, SecondaryActiveRecord::Type.lookup(:foo, adapter: :postgresql)
  end

  test "lookup defaults to the current adapter" do
    current_adapter = SecondaryActiveRecord::Base.connection.adapter_name.downcase.to_sym
    type = Struct.new(:args)
    adapter_type = Struct.new(:args)
    SecondaryActiveRecord::Type.register(:foo, type, override: false)
    SecondaryActiveRecord::Type.register(:foo, adapter_type, adapter: current_adapter)

    assert_equal adapter_type.new, SecondaryActiveRecord::Type.lookup(:foo)
  end
end
