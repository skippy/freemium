class Freemium::CouponReferral < Freemium::CouponReferral::Base
  set_table_name "freemium_coupon_referrals"
  
  # belongs_to :coupon, :class_name => 'Freemium::Coupon'
  # belongs_to :referring_user, :class_name => 'User'
  # belongs_to :subscription, :class_name => 'Freemium::Subscription'
  
end
