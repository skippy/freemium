class CreateFreemiumMigrations < ActiveRecord::Migration
  def self.up
    create_table "<%= subscription_singular_name %>_plans", :force => true do |t|
      t.column :name, :string, :null => false
      t.column :rate_cents, :integer, :null => false
      t.column :yearly, :boolean, :default => false
    end

    create_table "<%= subscription_plural_name %>", :force => true do |t|
      t.column :subscribable_id, :integer, :null => false
      t.column "<%= subscription_singular_name %>_plan_id", :integer, :null => false
      t.column :paid_through, :date, :null => false
      t.column :expire_on, :date, :null => true
      t.column :comped, :boolean, :default => false
      t.column :billing_key, :string, :null => true
      t.column :last_transaction_at, :datetime, :null => true
    end

    # for association queries
    # a user can have only ONE subscription plan at a time....
    add_index "<%= subscription_plural_name %>", :subscribable_id, :unique => true

    # for finding due, pastdue, and expiring subscriptions
    add_index "<%= subscription_plural_name %>", :paid_through
    add_index "<%= subscription_plural_name %>", :expire_on

    # for applying transactions from automated recurring billing
    add_index "<%= subscription_plural_name %>", :billing_key
    
    
    create_table "<%= coupon_plural_name %>", :force => true do |t|
      t.column :name, :string, :null => false
      t.column :coupon_code, :string, :null => false
      t.column :discount_rate_percent, :integer, :null => false
      t.column :span_num_days, :integer, :null => false
      t.column :usage_limit, :integer, :default => 0
      t.column :usage_counter, :integer, :default => 0
      t.column :expire_on, :date
      t.column :created_at, :datetime
    end
    
    create_table "<%= user_singular_name %>_<%= coupon_singular_name %>_referrals", :force => true do |t|
      t.column :subscribable_id, :integer
      t.column :subscription_id, :integer, :null => false
      t.column :coupon_id, :integer
      t.column :referring_user_id, :integer
      t.column :free_days, :integer, :null => false
      t.column :applied_on, :date
    end
        
     
    #lets add the referral code column to the user model
    add_column "<%= user_plural_name %>", :referral_code, :string
    <%= user_class_name %>.reset_column_information
    <%= user_class_name %>.send(:extend, Freemium::Acts::Subscriptable::SingletonMethods)
    <%= user_class_name %>.setup_referral_codes!
    
  end

  def self.down
    drop_table "<%= subscription_singular_name %>_plans"
    drop_table "<%= subscription_plural_name %>"
    
    drop_table "<%= coupon_plural_name %>"    
    drop_table "<%= user_singular_name %>_<%= coupon_singular_name %>_referrals"
    
    remove_column "<%= user_plural_name %>", :referral_code
    
  end
end
