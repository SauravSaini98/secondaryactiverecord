# frozen_string_literal: true

require "secondary_active_record/connection_adapters/postgresql/oid/array"
require "secondary_active_record/connection_adapters/postgresql/oid/bit"
require "secondary_active_record/connection_adapters/postgresql/oid/bit_varying"
require "secondary_active_record/connection_adapters/postgresql/oid/bytea"
require "secondary_active_record/connection_adapters/postgresql/oid/cidr"
require "secondary_active_record/connection_adapters/postgresql/oid/date"
require "secondary_active_record/connection_adapters/postgresql/oid/date_time"
require "secondary_active_record/connection_adapters/postgresql/oid/decimal"
require "secondary_active_record/connection_adapters/postgresql/oid/enum"
require "secondary_active_record/connection_adapters/postgresql/oid/hstore"
require "secondary_active_record/connection_adapters/postgresql/oid/inet"
require "secondary_active_record/connection_adapters/postgresql/oid/jsonb"
require "secondary_active_record/connection_adapters/postgresql/oid/money"
require "secondary_active_record/connection_adapters/postgresql/oid/oid"
require "secondary_active_record/connection_adapters/postgresql/oid/point"
require "secondary_active_record/connection_adapters/postgresql/oid/legacy_point"
require "secondary_active_record/connection_adapters/postgresql/oid/range"
require "secondary_active_record/connection_adapters/postgresql/oid/specialized_string"
require "secondary_active_record/connection_adapters/postgresql/oid/uuid"
require "secondary_active_record/connection_adapters/postgresql/oid/vector"
require "secondary_active_record/connection_adapters/postgresql/oid/xml"

require "secondary_active_record/connection_adapters/postgresql/oid/type_map_initializer"

module SecondaryActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
      end
    end
  end
end
