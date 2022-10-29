# frozen_string_literal: true

require "active_support/core_ext/module/attr_internal"
require "secondary_active_record/log_subscriber"

module SecondaryActiveRecord
  module Railties # :nodoc:
    module ControllerRuntime #:nodoc:
      extend ActiveSupport::Concern

    # TODO Change this to private once we've dropped Ruby 2.2 support.
    # Workaround for Ruby 2.2 "private attribute?" warning.
    protected

      attr_internal :db_runtime

    private

      def process_action(action, *args)
        # We also need to reset the runtime before each action
        # because of queries in middleware or in cases we are streaming
        # and it won't be cleaned up by the method below.
        SecondaryActiveRecord::LogSubscriber.reset_runtime
        super
      end

      def cleanup_view_runtime
        if logger && logger.info? && SecondaryActiveRecord::Base.connected?
          db_rt_before_render = SecondaryActiveRecord::LogSubscriber.reset_runtime
          self.db_runtime = (db_runtime || 0) + db_rt_before_render
          runtime = super
          db_rt_after_render = SecondaryActiveRecord::LogSubscriber.reset_runtime
          self.db_runtime += db_rt_after_render
          runtime - db_rt_after_render
        else
          super
        end
      end

      def append_info_to_payload(payload)
        super
        if SecondaryActiveRecord::Base.connected?
          payload[:db_runtime] = (db_runtime || 0) + SecondaryActiveRecord::LogSubscriber.reset_runtime
        end
      end

      module ClassMethods # :nodoc:
        def log_process_action(payload)
          messages, db_runtime = super, payload[:db_runtime]
          messages << ("SecondaryActiveRecord: %.1fms" % db_runtime.to_f) if db_runtime
          messages
        end
      end
    end
  end
end
