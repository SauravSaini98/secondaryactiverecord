# frozen_string_literal: true

module SecondaryActiveRecord
  module Type
    module Internal
      module Timezone
        def is_utc?
          SecondaryActiveRecord::Base.default_timezone == :utc
        end

        def default_timezone
          SecondaryActiveRecord::Base.default_timezone
        end
      end
    end
  end
end
