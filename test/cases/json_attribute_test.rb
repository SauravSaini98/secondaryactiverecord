# frozen_string_literal: true

require "cases/helper"
require "cases/json_shared_test_cases"

class JsonAttributeTest < SecondaryActiveRecord::TestCase
  include JSONSharedTestCases
  self.use_transactional_tests = false

  class JsonDataTypeOnText < SecondaryActiveRecord::Base
    self.table_name = "json_data_type"

    attribute :payload,  :json
    attribute :settings, :json

    store_accessor :settings, :resolution
  end

  def setup
    super
    @connection.create_table("json_data_type") do |t|
      t.string "payload"
      t.string "settings"
    end
  end

  private
    def column_type
      :string
    end

    def klass
      JsonDataTypeOnText
    end
end
