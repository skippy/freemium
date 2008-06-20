module Freemium
  class << self
    attr_reader :activity_log

    def with_activity_logging
      @activity_log = ActivityLog.new
      yield
      @activity_log = nil
    end
    
    def log_subscription_msg(subscription, msg)
      RAILS_DEFAULT_LOGGER.debug "FreemiumLogger:: (subscription ##{subscription.id}): #{msg}"
      return unless log?
      activity_log[subscription] << msg
    end
    
    def log_test_msg(msg)
      RAILS_DEFAULT_LOGGER.debug("FreemiumLog (TEST MSG):: #{msg}") if Freemium.gateway.in_test_mode?
    end
    
    def log_msg(msg)
      RAILS_DEFAULT_LOGGER.debug("FreemiumLog:: #{msg}") if Freemium.gateway.in_test_mode?
    end
    
    def log?
      admin_report_recipients and @activity_log
    end
  end

  class ActivityLog
    include Enumerable
    def events_by_subscription
      @events_by_subscription ||= {}
    end

    def [](subscription)
      events_by_subscription[subscription] ||= []
    end

    def each
      events_by_subscription.each{|subscription, events| yield subscription, events}
    end
  end
end