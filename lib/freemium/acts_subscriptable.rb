module Freemium
  
  module Acts
    module Subscriptable

      def self.included(base)
        base.extend(ClassMethods)  
      end

      module ClassMethods
        def acts_as_subscriptable(options = {})
          subscription_model = options[:subscriptable] || :subscription
          coupon_referrals_model = options[:coupon] || :coupon
          coupon_referrals_model = "#{class_name.underscore}_#{coupon_referrals_model}_referrals"
          
          
          write_inheritable_attribute(:acts_as_subscriptable_options, {
            :subscriptable_type => class_name.to_s,
            :subcription_model_name => subscription_model,
            :coupon_referrals_model_name => coupon_referrals_model
          })          
          class_inheritable_reader :acts_as_subscriptable_options
          
          
          has_one   subscription_model,      :dependent => :destroy, :foreign_key => :subscriptable_id
          has_many  coupon_referrals_model, :dependent => :destroy, :foreign_key => :subscriptable_id
          
          validates_uniqueness_of :referral_code, :case_sensitive => false, :allow_blank => true
          validates_format_of     :referral_code, :with => /\A#{Freemium.referral_code_prefix}/, :message => "must start with '#{Freemium.referral_code_prefix}'"


          include Freemium::Acts::Subscriptable::InstanceMethods
          extend Freemium::Acts::Subscriptable::SingletonMethods
        end
      end

      module SingletonMethods
        
        def setup_referral_codes!
          #do this in case the user has not added acts_as_subscriptable yet....
          send(:include, Freemium::Acts::Subscriptable::InstanceMethods)
          find(:all, :select => 'id').each{|u| u.reset_referral_code!}
        end
        
      end

      module InstanceMethods
        
        #force referral_code to start with 'ref' so we can differentiate between a coupon and a referral code..
        #allows ability to combine coupon and referral code into one field...easier for users.
        def reset_referral_code!
          require 'rails_generator/secret_key_generator'
          init_token_size = 7
          token = Freemium.referral_code_prefix + Rails::SecretKeyGenerator.new(Time.now.to_i).generate_secret
          self[:referral_code] = token[0..init_token_size]
          counter = 0
          finder_class = [self.class].detect { |klass| !klass.abstract_class? }
          conditions = ["referral_code = ?", self[:referral_code]]

          #hmmm...what do we do if we can't find a unique token?
          while counter < 10 && (finder_class.find(:first, :select => 1, :conditions => conditions))
            token = Rails::SecretKeyGenerator.new(Time.now.to_i).generate_secret
            self[:referral_code] = Freemium.referral_code_prefix + token[0..(init_token_size + counter)]
            counter += 1
          end
          self.save_without_validation
        end
        
        def apply_coupon_referral_code?(code)
          subscription_ = self.send("#{acts_as_subscriptable_options[:subcription_model_name]}")
          
          return false if subscription.blank?
          if code.start_with?(Freemium.referral_code_prefix)
            #lets check referrals
            u = User.find_by_referral_code(code)
            return false if u.blank?
            eval("self.#{acts_as_subscriptable_options[:coupon_referrals_model_name]}.build(:referring_user_id => u.id, :#{acts_as_subscriptable_options[:subcription_model_name]} => subscription)")
          else
            c = Coupon.find_by_coupon_code(code)
            return false if c.blank?
            eval("self.#{acts_as_subscriptable_options[:coupon_referrals_model_name]}.build(:coupon_id => c.id, :#{acts_as_subscriptable_options[:subcription_model_name]} => subscription)")
          end
        end
        
      end



    end
  end

end