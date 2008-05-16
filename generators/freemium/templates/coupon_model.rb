class <%= coupon_class_name %> < Freemium::Coupon
  has_many :<%= user_singular_name %>_<%= coupon_singular_name %>_referrals
  
end