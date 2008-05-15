module Freemium
  # == Schema Information
  # Schema version: 93
  #
  # Table name: user_coupons
  #
  #  id                :integer(11)   not null, primary key
  #  payment_id        :integer(11)   
  #  coupon_id         :integer(11)   
  #  referring_user_id :integer(11)   
  #  applied_on        :date          
  #  created_at        :datetime      
  #  updated_at        :datetime      
  #

  class UserCouponReferral < ActiveRecord::Base
    acts_as_paranoid :with => :applied_on
    belongs_to :coupon
    # belongs_to :payment
    belongs_to :referring_user, :class_name => 'User'

    validates_presence_of :payment_id
    validates_presence_of :coupon_id, :if => Proc.new{|model| model.referring_user_id.nil?}
    validates_presence_of :referring_user_id, :if => Proc.new{|model| model.coupon_id.nil?}

    validates_uniqueness_of :coupon_id, :referring_user_id, :scope => [:payment_id], :allow_blank => true

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