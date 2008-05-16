class <%= user_class_name + coupon_class_name%>Referral < Freemium::UserCouponReferral
  set_table_name "<%= user_coupon_plural_name %>"
  
  belongs_to :coupon, :class_name => '<%= coupon_class_name %>'
  belongs_to :referring_user, :class_name => '<%= user_class_name %>'
  belongs_to :subscription, :class_name => '<%= subscription_class_name %>'
  
end
