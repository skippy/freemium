# == Schema Information
# Schema version: 93
#
# Table name: coupons
#
#  id                    :integer(11)   not null, primary key
#  name                  :string(255)   
#  coupon_code           :string(40)    
#  discount_rate_percent :integer(11)   
#  span_num_days         :integer(11)   
#  usage_limit           :integer(11)   default(0)
#  usage_counter         :integer(11)   default(0)
#  expires_on            :date          
#  created_at            :datetime      
#  updated_at            :datetime      
#
module Freemium
  class Coupon < ActiveRecord::Base
    has_many :user_coupons

    validates_presence_of :name, :coupon_code
    validates_uniqueness_of :name, :coupon_code
    validates_length_of :coupon_code, :minimum => 3


    # class << self
    #   def create_coupon_code
    #     coupon_code = nil
    #     while(true)
    #       coupon_code = UUID.timestamp_create.to_s[0..4].upcase
    #       #do not allow zero's or O's, and make sure it contains some numbers and some letters
    #       next if coupon_code =~ /0|o/i
    #       next unless coupon_code =~ /[0-9]/
    #       next unless coupon_code =~ /[a-z]/i
    #       cc = Coupon.new(:coupon_code => coupon_code)
    #       cc.valid?
    #       coupon_code = cc.errors.on(:coupon_code).blank? ? coupon_code : nil
    #       return coupon_code unless coupon_code.nil?
    #     end
    #   end
    # end
    # 

  end
end