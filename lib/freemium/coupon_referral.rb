module Freemium
  class CouponReferral < ActiveRecord::Base
    set_table_name 'freemium_coupon_referrals'

    validates_presence_of :subscription_id, :free_days
    validates_presence_of :coupon_id, :if => Proc.new{|model| model.referring_user_id.nil?}
    validates_presence_of :referring_user_id, :if => Proc.new{|model| model.coupon_id.nil?}

    validates_uniqueness_of :coupon_id, :referring_user_id, :scope => [:subscription_id], :allow_blank => true
    
    def discount_rate_percent
      coupon ? coupon.discount_rate_percent : 100
    end

    protected

    def after_create
      coupon.increment!(:usage_counter) if coupon
    end

  end
  
end