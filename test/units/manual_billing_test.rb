require File.dirname(__FILE__) + '/../test_helper'

class ManualBillingTest < Test::Unit::TestCase
  fixtures :users, :subscriptions, :subscription_plans

  class Subscription < ::Subscription
    include Freemium::ManualBilling
  end

  def test_find_subscriber
    Subscription.any_instance.stubs(:charge!).returns(true)

    # making a one-off fixture set, basically
    create_subscriber_subscription # this subscription should be subscriber
    create_subscriber_subscription(:paid_through => Date.today) # this subscription should be subscriber
    create_subscriber_subscription(:subscription_plan => subscription_plans(:free)) # shouldn't be subscriber because it's free
    create_subscriber_subscription(:paid_through => Date.today + 1) # shouldn't be subscriber because it's paid far enough out
    create_subscriber_subscription(:expires_on => Date.today + 1) # shouldn't be subscriber because it's already expiring

    expirable = Subscription.send(:find_subscriber)
    assert expirable.all? {|subscription| subscription.subscription_plan.rate_cents > 0}, "free subscriptions aren't subscriber"
    assert expirable.all? {|subscription| subscription.paid_through <= Date.today}, "subscriptions paid through tomorrow aren't subscriber yet"
    assert expirable.all? {|subscription| !subscription.expires_on or subscription.expires_on < subscription.paid_through}, "subscriptions already expiring aren't subscriber"
  end

  def test_charging_a_subscription
    subscription = Subscription.find(:first)
    paid_through = subscription.paid_through
    Freemium.gateway.stubs(:charge).returns(
      Freemium::Transaction.new(
        :billing_key => subscription.billing_key,
        :amount => subscription.subscription_plan.rate,
        :success => true
      )
    )

    assert_nothing_raised do subscription.charge! end
    assert_equal (paid_through >> 1).to_s, subscription.reload.paid_through.to_s, "extended by a month"
  end

  def test_failing_to_charge_a_subscription
    subscription = Subscription.find(:first)
    paid_through = subscription.paid_through
    Freemium.gateway.stubs(:charge).returns(
      Freemium::Transaction.new(
        :billing_key => subscription.billing_key,
        :amount => subscription.subscription_plan.rate,
        :success => false
      )
    )

    assert_nil subscription.expires_on
    assert_nothing_raised do subscription.charge! end
    assert_equal paid_through, subscription.reload.paid_through, "not extended"
    assert_not_nil subscription.expires_on
  end

  def test_run_billing_calls_charge_on_subscriber
    subscription = Subscription.find(:first)
    Subscription.stubs(:find_subscriber).returns([subscription])
    subscription.expects(:charge!).once
    Subscription.send :run_billing
  end

  def test_run_billing_sends_report
    Freemium.stubs(:admin_report_recipients).returns("test@example.com")
    Freemium.mailer.expects(:deliver_admin_report)
    Subscription.send :run_billing
  end

  protected

  def create_subscriber_subscription(options = {})
    Subscription.create({
      :subscription_plan => subscription_plans(:premium),
      :subscriber => User.new(:name => 'a'),
      :paid_through => Date.today - 1,
      :billing_key => 'ninerfivebravo'
    }.merge(options))
  end
end