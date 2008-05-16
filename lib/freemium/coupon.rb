module Freemium
  class Coupon < ActiveRecord::Base

    validate :valid_coupon_code

    validates_presence_of :name, :coupon_code, :span_num_days
    validates_uniqueness_of :name, :coupon_code
    validates_length_of :coupon_code, :minimum => 3
    
    protected
    
    def valid_coupon_code
      return true if coupon_code.blank? || !coupon_code.start_with?(Freemium.referral_code_prefix)
      errors.add :coupon_code, "cannot start with #{Freemium.referral_code_prefix}, which conflicts with referral codes"
    end

  end
end