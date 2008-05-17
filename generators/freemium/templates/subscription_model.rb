class Freemium::Subscription < Freemium::Subscription::Base
  set_table_name "freemium_subscriptions"

  # belongs_to :subscriber, :class_name => 'User'
  # has_many :user_coupon_referrals, :class_name => 'Freemium::CouponReferral'


  #A list of helpful methods that are inherited are listed below.
  #
  # GETTING STARTED
  #
  # 1) add this line to your <%= user_class_name %> model:
  #       acts_as_subscriber
  #
  # 2) create a new subscription for a user:
  #       s = Freemium::Subscription.create(:subscriber => user, :subscription_plan => super_duper_plan)
  #
  # 3) pass in the credit care information when ready
  #       s.credit_card = Freemium::Subscription.sample_cc_information
  #    this method takes  Freemium::CreditCard object or a valid hash of objects
  #
  # 4) lets charge some users! (you can do this from a cron job)
  #       Freemium::Subscription.run_billing
  #
  # That is it!  There are various helper methods in case you need to know how much time is remaining, 
  #  has their card expired, etc, but this is the meat of it!
  # 

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
  
  ##
  ## Receiving More Money
  ##

  # receives payment and saves the record
  # def receive_payment!(value)


  ##
  ## Remaining Time
  ##

  # returns the value of the time between now and paid_through.
  # will optionally interpret the time according to a certain subscription plan.
  # def remaining_value(subscription_plan_id = self.subscription_plan_id)


  # if paid through today, returns zero
  # def remaining_days

  ##
  ## Grace Period
  ##

  # if under grace through today, returns zero
  # def remaining_days_of_grace

  # def in_grace?

  ##
  ## Expiration
  ##

  # expires all subscriptions that have been pastdue for too long (accounting for grace)
  # def self.expire

  # sets the expiration for the subscription based on today and the configured grace period.
  # def expire_after_grace!

  # sends an expiration email, then downgrades to a free plan
  # def expire!

  # def expired?

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
  # def credit_card=(cc)
end