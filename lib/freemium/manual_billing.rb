module Freemium
  # adds manual billing functionality to the Subscription class
  module ManualBilling
    def self.included(base)
      base.extend ClassMethods
    end

    # charges this subscription.
    # assumes, of course, that this module is mixed in to the Subscription model
    def charge!
      self.class.transaction do
        return if used_comp?
        if subscriber.blank?
          # something happened where the attached user no longer exists....
          # do not do anything, but log it so the admin can decide what to do?
          Freemium.log_subscription_msg(self, "Subscriber (id: #{subscriber_id}, type: #{subscriber_type}) is no longer found.  Deleting this subscription (id: #{self.id}).")
          self.destroy
          return
        end
        
        if billing_key.blank?
          expire_after_grace! #if self.expires_on.blank? || self.expires_on <= Date.today
          return 
        end
        # attempt to bill (use gateway)
        transaction = Freemium.gateway.charge(billing_key, subscription_plan.rate)
        Freemium.log_subscription_msg(self, transaction)
        transaction.success? ? receive_payment!(transaction.amount) : expire_after_grace!
      end
    end

    module ClassMethods
      # the process you should run periodically
      def run_billing
        Freemium.with_activity_logging do
          # charge all subscriber subscriptions
          find_subscriber.each(&:charge!)
          # actually expire any subscriptions whose time has come
          expire

          # send the activity report
          Freemium.mailer.deliver_admin_report(
            Freemium.admin_report_recipients,
            Freemium.activity_log
          ) if Freemium.admin_report_recipients
        end
      end

      protected

      # a subscription is due on the last day it's paid through. so this finds all
      # subscriptions that expire the day *after* the given date. note that this
      # also finds past-due subscriptions, as long as they haven't been set to
      # expire.
      def find_subscriber(date = Date.today)
        find(
          :all,
          :include => :subscription_plan,
          # :conditions => ['freemium_subscription_plans.rate_cents > 0 AND paid_through <= ?', date.to_date]
          :conditions => ["freemium_subscription_plans.rate_cents > 0 AND paid_through <= ? AND (state_dsc is null OR state_dsc != 'expired') AND (expires_on IS NULL or expires_on <= paid_through)", date.to_date]
        )
      end
    end
  end
end