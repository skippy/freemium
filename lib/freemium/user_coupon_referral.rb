module Freemium
  class UserCouponReferral < ActiveRecord::Base
    # acts_as_paranoid :with => :applied_on

    REFERALL_TIME_FRAME = 30

    def span_days
      tf = REFERALL_TIME_FRAME
      tf = coupon.span_num_days if coupon
      tf
    end

    def discount_rate_percent
      coupon ? coupon.discount_rate_percent : 100
    end




    protected

    def after_create
      coupon.increment!(:usage_counter)
    end

  end
  
end