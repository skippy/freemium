class Freemium::Coupon < Freemium::Coupon::Base
  set_table_name "freemium_coupons"
  
  has_many :freemium_coupon_referrals
  
end