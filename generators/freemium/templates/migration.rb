class <%= migration_name %> < ActiveRecord::Migration
  def self.up
    create_table "<%= subscription_singular_name %>_plans", :force => true do |t|
      t.column :name, :string, :null => false
      t.column :rate_cents, :integer, :null => false
      t.column :yearly, :boolean, :null => false
    end

    create_table "<%= subscription_plural_name %>", :force => true do |t|
      t.column :subscribable_id, :integer, :null => false
      t.column :subscribable_type, :string, :null => false
      t.column "<%= subscription_singular_name %>_plan_id", :integer, :null => false
      t.column :paid_through, :date, :null => false
      t.column :expire_on, :date, :null => true
      t.column :billing_key, :string, :null => true
      t.column :last_transaction_at, :datetime, :null => true
    end

    # for polymorphic association queries
    add_index "<%= subscription_plural_name %>", :subscribable_id
    add_index "<%= subscription_plural_name %>", :subscribable_type

    # for finding due, pastdue, and expiring subscriptions
    add_index "<%= subscription_plural_name %>", :paid_through
    add_index "<%= subscription_plural_name %>", :expire_on

    # for applying transactions from automated recurring billing
    add_index "<%= subscription_plural_name %>", :billing_key
  end

  def self.down
    drop_table "<%= subscription_singular_name %>_plans"
    drop_table "<%= subscription_plural_name %>"
  end
end
