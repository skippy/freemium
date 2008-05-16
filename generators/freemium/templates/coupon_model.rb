class <%= coupon_class_name %> < Freemium::Coupon
  set_table_name "<%= coupon_plural_name %>"
  
  has_many :<%= user_singular_name %>_<%= coupon_singular_name %>_referrals
  
end