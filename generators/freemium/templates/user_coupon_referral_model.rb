class <%= user_class_name + coupon_class_name%>Referral < Freemium::UserCouponReferral
  
  belongs_to :<%= coupon_singular_name %>
  belongs_to :referring_user, :class_name => '<%= user_class_name %>'
  
  
  
  validates_presence_of :<%= subscription_singular_name %>_id
  validates_presence_of :<%= coupon_singular_name %>_id, :if => Proc.new{|model| model.referring_user_id.nil?}
  validates_presence_of :referring_user_id, :if => Proc.new{|model| model.<%= coupon_singular_name %>_id.nil?}

  validates_uniqueness_of :<%= coupon_singular_name %>_id, :referring_user_id, :scope => [:<%= subscription_singular_name %>_id], :allow_blank => true

  
end
