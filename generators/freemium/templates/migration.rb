class CreateFreemiumMigrations < ActiveRecord::Migration
  def self.up
    <% unless user_class_name.blank? -%>
     # lets add the referral code column to the user model
     add_column :<%= user_plural_name %>, :referral_code, :string
     <%= user_class_name %>.reset_column_information
     #NOTE: not sure why, but I need to call the referral_code directly,
     #      otherwise it is not picked up in setup_referral_codes!
     u = <%= user_class_name %>.new
     u.referral_code = 'here'
     <%= user_class_name %>.send(:acts_as_subscriber)
     <%= user_class_name %>.setup_referral_codes!
   <% end -%>

    create_table :freemium_subscriptions, :force => true do |t|
      t.column :subscriber_id, :integer, :null => false
      t.column :subscriber_type, :string, :null => false
      t.column :subscription_plan_id, :integer, :null => false
      t.column :state_dsc, :string
      t.column :payment_cents, :integer
      t.column :paid_through, :date, :null => false
      t.column :cc_digits_last_4, :integer, :limit => 4
      t.column :cc_type,          :string, :limit => 25
      t.column :expires_on, :date, :null => true
      t.column :comped, :boolean, :default => false
      t.column :in_trial, :boolean, :default => false
      t.column :billing_key, :string, :null => true
      t.column :last_transaction_at, :datetime, :null => true
      <% if options[:acts_as_versioned_enabled] -%>
    t.column :version,        :integer
      <% end -%>
      <% if options[:acts_as_paranoid_enabled] -%>
    t.column :deleted_at,        :datetime
      <% end -%>
    end
    
    <% if options[:acts_as_versioned_enabled] -%>
      FreemiumSubscription.create_versioned_table
    <% end -%>

    create_table :freemium_subscription_plans, :force => true do |t|
      t.column :name, :string, :null => false
      t.column :rate_cents, :integer, :null => false
      t.column :yearly, :boolean, :default => false
    end

    # for association queries
    # a user can have only ONE subscription plan at a time....
    add_index :freemium_subscriptions, :subscriber_id, :unique => true

    # for finding due, pastdue, and expiring subscriptions
    add_index :freemium_subscriptions, :paid_through
    add_index :freemium_subscriptions, :expires_on

    # for applying transactions from automated recurring billing
    add_index :freemium_subscriptions, :billing_key
    
    
    create_table :freemium_coupons, :force => true do |t|
      t.column :name, :string, :null => false
      t.column :coupon_code, :string, :null => false
      t.column :discount_rate_percent, :integer, :null => false
      t.column :span_num_days, :integer, :null => false
      t.column :usage_limit, :integer, :default => 0
      t.column :usage_counter, :integer, :default => 0
      t.column :expires_on, :date
      t.column :created_at, :datetime
    end
    
    create_table :freemium_coupon_referrals, :force => true do |t|
      t.column :subscription_id, :integer, :null => false
      t.column :coupon_id, :integer
      t.column :referring_user_id, :integer
      t.column :free_days, :integer, :null => false
      t.column :applied_on, :date
    end
        
  end

  def self.down
    drop_table :freemium_subscription_plans
    drop_table :freemium_subscriptions
    <% if options[:acts_as_versioned_enabled] -%>
      FreemiumSubscription.drop_versioned_table
    <% end -%>
    
    drop_table :freemium_coupons
    drop_table :freemium_coupon_referrals
    
    <% unless user_class_name.blank? -%>
    remove_column :<%= user_plural_name %>, :referral_code
    <% end -%>
  end
end
