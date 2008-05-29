module Freemium
  class CreditCardStorageError < RuntimeError; end

  class << self
    # Lets you configure which ActionMailer class contains appropriate
    # mailings for invoices, expiration warnings, and expiration notices.
    # You'll probably want to create your own, based on lib/subscription_mailer.rb.
    attr_accessor :mailer

    # The gateway of choice. Default gateway is a stubbed testing gateway.
    attr_writer :gateway
    def gateway
      @gateway ||= Freemium::Gateways::Test.new
    end

    # You need to specify whether Freemium or your gateway's ARB module will control
    # the billing process. If your gateway's ARB controls the billing process, then
    # Freemium will simply try and keep up-to-date on transactions.
    def billing_recurrence_mode=(val)
      case val
        when :manual:   FreemiumSubscription.send(:include, Freemium::ManualBilling)
        when :gateway:  FreemiumSubscription.send(:include, Freemium::RecurringBilling)
        else raise "unknown billing_recurrence_mode: #{val}"
      end
    end
    
    # When the card is stored, it is normally not validated.  Enable this option to run a check
    # against the issuing bank to validate the credit card.  This is done by running an authorization
    # check for $1.
    attr_writer :validate_card_during_store
    def validate_card_during_store
      @validate_card_during_store ||= true
    end
    

    # How many days to keep an account active after it fails to pay.
    attr_writer :days_grace
    def days_grace
      @days_grace ||= 3
    end

    #days to offer in free trial
    attr_writer :days_free_trial
    def days_free_trial
      @days_free_trial ||= 0
    end
    
    # What plan to assign to subscriptions that have expired. May be nil.
    def expired_plan
      return nil if @expired_plan == :nil
      @expired_plan ||= FreemiumSubscriptionPlan.find(:first, :conditions => "rate_cents = 0")
    end

    def expired_plan=(plan)
      @expired_plan = plan.blank? ? :nil : plan
    end
    
    # force the referral_code to have a different format than a coupon code...
    # allows the ability to have one point of entry for both coupons and referral codes
    attr_writer :referral_code_prefix
    def referral_code_prefix
      @referral_code_prefix ||= 'ref'
    end

    # how many days should a referral count for?
    # we have separate counters for the number of free days
    # for the user who is using the referrer code and the
    # person who's referrer code is beng used
    #
    # both default to 30 days
    attr_writer :referral_days_for_applied_user
    def referral_days_for_applied_user
      @referral_days_for_applied_user ||= 30
    end

    attr_writer :referral_days_for_referred_user
    def referral_days_for_referred_user
      @referral_days_for_referred_user ||= 30
    end
    
    # If you want to receive admin reports, enter an email (or list of emails) here.
    # These will be bcc'd on all SubscriptionMailer emails, and will also receive the
    # admin activity report.
    attr_accessor :admin_report_recipients
  end
end

require File.join(File.dirname(__FILE__), 'activity_logger')