# == Attributes
#   subscriber:         the model in your system that has the subscription. probably a User.
#   subscription_plan:    which service plan this subscription is for. affects how payment is interpreted.
#   paid_through:         when the subscription currently expires, assuming no further payment. for manual billing, this also determines when the next payment is due.
#   billing_key:          the id for this user in the remote billing gateway. may not exist if user is on a free plan.
#   last_transaction_at:  when the last gateway transaction was for this account. this is used by your gateway to find "new" transactions.
#
class FreemiumSubscription < ActiveRecord::Base
  #allows us to make sure we don't save versions if things haven't changed!
  #we call save on this object a lot to save instantiated but unsaved children
  #but we don't want to version that!
  acts_as_versioned :if_changed => [:subscription_plan_id, :state_dsc, :payment_cents, :paid_through, :billing_key, :comped, :in_trial ] rescue nil    
  acts_as_paranoid rescue nil #in case it doesn't exist...


  belongs_to :subscription_plan, :class_name => 'FreemiumSubscriptionPlan', :foreign_key => 'subscription_plan_id'
  belongs_to :subscriber, :polymorphic => true
  has_many :coupon_referrals, :class_name => 'FreemiumCouponReferral', :foreign_key => 'subscription_id'
  
  composed_of :payment, :class_name => 'Money', :mapping => [ %w(payment_cents cents) ], :allow_nil => true
  
  before_validation :set_paid_through
  before_save :process_cc
  before_create :setup_free_trial_period
  after_destroy :cancel_in_remote_system

  validates_presence_of :subscriber_id
  validates_presence_of :subscription_plan_id
  validates_presence_of :paid_through

  attr_reader :previously_paid_on, :credit_card

  ##
  ## Receiving More Money
  ##

  def self.sample_cc_information
    #for braintree....
    { 
      :first_name => 'First Name', 
      :last_name  => 'Last Name', 
      :type       => 'visa',
      :number     => '4111111111111111', 
      :month      => '10', 
      :year       => '2010', 
      :verification_value => '999' 
    }
  end

  def self.setup_cc(cc={})
    Freemium::CreditCard.new(cc)
  end

  # receives payment and saves the record
  #
  # extends the paid_through period according to how much money was received.
  # when possible, avoids the days-per-month problem by checking if the money
  # received is a multiple of the plan's rate.
  #
  # really, i expect the case where the received payment does not match the
  # subscription plan's rate to be very much an edge case.
  def receive_payment!(value)
    self.paid_through = if value.cents % subscription_plan.rate.cents == 0
      months_per_multiple = subscription_plan.yearly? ? 12 : 1
      self.paid_through >> months_per_multiple * value.cents / subscription_plan.rate.cents
    else
      # edge case
      self.paid_through + (value.cents / subscription_plan.daily_rate.cents)
    end

    # if they've paid again, then reset expiration
    self.expires_on = nil
    self.last_transaction_at = Time.now
    self.comped = false
    self.in_trial = false
    self.payment_cents = value.cents

    Freemium.log_subscription_msg(self, "now paid through #{self.paid_through}")

    self.state_dsc = 'paid'
    save!

    # sends an invoice for the specified amount.
    Freemium.mailer.deliver_invoice(subscriber, self, value)
  end

  ##
  ## Comp: coupons and referral codes
  ##

  def has_comps_to_use?    
    self.coupon_referrals.count(:conditions => {:applied_on => nil}) > 0
  end

  def used_comp?
    comp = self.coupon_referrals.find(:first, :conditions => {:applied_on => nil})
    return false unless comp
    saved = false
    transaction do
      comp.update_attribute(:applied_on, Time.now)
      start_time = (self.paid_through && self.paid_through > Date.today) ? self.paid_through : Time.now
      self.paid_through = start_time + comp.free_days.days
      self.comped = true
      self.in_trial = false
      # if they've paid again, then reset expiration
      self.expires_on = nil
      self.payment_cents = 0
      self.last_transaction_at = Time.now
      self.state_dsc = comp.is_coupon? ? 'used coupon' : 'used referral'
      saved = self.save        
    end
    if saved
      Freemium.log_subscription_msg(self, "comp'ed through #{self.paid_through}")
      #do we want to setup an email to send out?
      # sends an invoice for the specified amount.
      # Freemium.mailer.deliver_invoice(subscriber, self, value)
    end
    saved
  end
  
  def give_complementary_subscription_period!(free_time=30.days)
    start_time = (self.paid_through && self.paid_through > Date.today) ? self.paid_through : Time.now
    self.paid_through = start_time + free_time
    self.comped = true
    self.in_trial = false
    # if they've paid again, then reset expiration
    self.expires_on = nil
    self.payment_cents = 0
    self.last_transaction_at = Time.now
    self.state_dsc = "Complementary #{free_time / 1.day} free days."
    self.save!
  end
  
  def paid_through=(time)
    @previously_paid_on = self.paid_through
    self[:paid_through] = time
  end

  ##
  ## Remaining Time
  ##

  # returns the value of the time between now and paid_through.
  # will optionally interpret the time according to a certain subscription plan.
  def remaining_value(subscription_plan_id = self.subscription_plan_id)
    SubscriptionPlan.find(subscription_plan_id).daily_rate * remaining_days
  end

  # if paid through today, returns zero
  def remaining_days
    (self.paid_through.to_date - Date.today).to_i rescue 0
  end

  ##
  ## Grace Period
  ##

  # if under grace through today, returns zero
  def remaining_days_of_grace
    self.expires_on.blank? ? 0 : self.expires_on - Date.today - 1
  end

  def in_grace?
    remaining_days < 0 and not expired?
  end

  ##
  ## Expiration
  ##

  # expires all subscriptions that have been pastdue for too long (accounting for grace), also making sure we
  # don't call it multiple times
  def self.expire
    find(:all, :conditions => ["(state_dsc is null OR state_dsc != 'expired') AND expires_on >= paid_through AND expires_on <= ?", Date.today]).each(&:expire!)
  end

  # sets the expiration for the subscription based on today and the configured grace period.
  def expire_after_grace!
    self.state_dsc = 'expiring soon'
    self.expires_on = [Date.today, paid_through].max + Freemium.days_grace
    Freemium.log_subscription_msg(self, "now set to expire on #{self.expires_on}")
    Freemium.mailer.deliver_expiration_warning(subscriber, self)
    save_without_revision!
  end

  # sends an expiration email, then downgrades to a free plan
  def expire!
    Freemium.log_subscription_msg(self, "expired!")
    Freemium.mailer.deliver_expiration_notice(subscriber, self)
    # downgrade to a free plan, IF one is specified
    self.subscription_plan = Freemium.expired_plan if Freemium.expired_plan
    self.state_dsc = 'expired'
    
    # cancel whatever in the gateway
    cancel_in_remote_system
    # throw away this billing key (they'll have to start all over again)
    self.billing_key = nil
    # save all changes
    self.save!
  end

  def expired?
    (expires_on and expires_on <= Date.today) ? true : false
  end
  
  
  # let us know that when this period is over, that we will be able to process.  
  # helpful to let us know if the user is still in a free trial, but they are set
  # to go directly into a paid offering.
  def ready_to_process?
    !billing_key.blank?
  end
  
  #let us know if we will be processing this in the next recurring billing call....
  def going_to_process?
    (billing_key && subscription_plan.rate_cents > 0 && (paid_through <= Date.today || (expires_on && expires_on < paid_through)))
  end

  # Simple assignment of a credit card. Note that this may not be
  # useful for your particular situation, especially if you need
  # to simultaneously set up automated recurrences.
  #
  # Because of the third-party interaction with the gateway, you
  # need to be careful to only use this method when you expect to
  # be able to save the record successfully. Otherwise you may end
  # up storing a credit card in the gateway and then losing the key.
  #
  # NOTE: Support for updating an address could easily be added
  # with an "address" property on the credit card.
  def credit_card=(cc)
    @credit_card = cc.is_a?(Freemium::CreditCard) ? cc : Freemium::CreditCard.new(cc)
  end
  
  def ip=(ip_address)
    @ip = ip_address
  end
  
  def setup_free_trial_period
    self.paid_through = Date.today + Freemium.days_free_trial.days
    self.expires_on = nil
    self.state_dsc = (Freemium.days_free_trial > 0) ? 'trial' : 'initial'
    self.in_trial = (Freemium.days_free_trial > 0)
  end
    
  def self.free_trial_ends_on
    Date.today + Freemium.days_free_trial.days
  end
  
  
  protected

  def process_cc
    return true unless @credit_card
    options = {:credit_card => @credit_card, :ip => @ip, :billing_key => billing_key}
    if Freemium.validate_card_during_store
      options[:type] = 'auth'
      options[:amount] = '1.00'
    end
    response = (billing_key) ? Freemium.gateway.update(billing_key, options) : Freemium.gateway.store(@credit_card, options)
    Freemium.log_subscription_msg(self, "Processing credit card (#{Freemium.validate_card_during_store ? "authorized cc for 1.00" : 'just saving cc'}).  Success? #{response.success?}.  code: #{response['response_code']}, msg: '#{response.message}'")

    raise Freemium::CreditCardStorageError.new(response.cleaned_message, response) unless response.success?   

    self.state_dsc = (billing_key) ? 'updated credit card' : 'saved credit card'
    
    self.billing_key = response.billing_key
    self.cc_digits_last_4 = @credit_card.last_digits
    self.cc_type = @credit_card.type
    # IF expired, lets reset their paid_through date...
    # this is for the case where they wait, say a week, after they receive their expired email
    # and if they haven't previously paid, lets not start the payment period a week ago!
    self.paid_through = Date.today if expired?
    self.expires_on = nil
    return true
  end

  def set_paid_through
    self.paid_through ||= Date.today
  end
  
  def cancel_in_remote_system
    Freemium.gateway.cancel(self.billing_key)
  end
end
