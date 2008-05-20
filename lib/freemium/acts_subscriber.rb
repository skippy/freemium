module Freemium
  class ReferralNotAppliedException < Exception #:nodoc:
  end
  
  class CouponNotAppliedException < Exception #:nodoc:
  end
  
  module Acts
    module Subscriber

      def self.included(base)
        base.extend(ClassMethods)  
      end

      module ClassMethods
        def acts_as_subscriber(options = {})
          get_referral_code_method = options[:get_referral_code]
          set_referral_code_method = options[:set_referral_code]
          find_referral_code_method = options[:find_referral_code]
          referral_code_column_name = options[:referral_code_column]
          referral_code_column_name ||= 'referral_code' if self.column_names.include?('referral_code') 
          if referral_code_column_name
            get_referral_code_method ||= referral_code_column_name
            set_referral_code_method ||= "#{referral_code_column_name}="
            find_referral_code_method ||= "#{self.class_name}.find_by_#{referral_code_column_name}"
          end
          #TODO: do some cleanup to make sure they are methods?
          referral_code_enabled = !(get_referral_code_method.blank? || set_referral_code_method.blank? || find_referral_code_method.blank?)

          write_inheritable_attribute(:acts_as_subscriber_options, {
            :referral_code_enabled => referral_code_enabled,
            :get_referral_code => get_referral_code_method,
            :set_referral_code => set_referral_code_method,
            :find_referral_code => find_referral_code_method,
            :disable_referral_when_method => options[:disable_referral_when]
          })          
          class_inheritable_reader :acts_as_subscriber_options
          
          has_one :subscription, :class_name => 'FreemiumSubscription', :dependent => :destroy, :as => :subscriber
          attr_accessor :coupon
          after_save :handle_coupon!
          
          if referral_code_enabled
            # this is REALLY expensive to setup...do we want to enforce it or make it optional?
            before_create :setup_referral_code
            
            validates_each :referral_code, :allow_blank => true do |record, attr, value|
              u = eval("#{acts_as_subscriber_options[:find_referral_code]} '#{record.send(acts_as_subscriber_options[:get_referral_code])}'")
              record.errors.add(attr, ActiveRecord::Errors.default_error_messages[:taken]) if u && u.id != record.id
            end
            
            # validates_uniqueness_of get_referral_code_method, :case_sensitive => false, :allow_blank => true
            validates_format_of     get_referral_code_method, :with => /\A#{Freemium.referral_code_prefix}/, :message => "must start with '#{Freemium.referral_code_prefix}'", :allow_blank => true
            
            after_save :save_referring_user!
          end
          
          include Freemium::Acts::Subscriber::InstanceMethods
          include Freemium::Acts::Subscriber::InstanceReferralCodeMethods if acts_as_subscriber_options[:referral_code_enabled]
          extend Freemium::Acts::Subscriber::SingletonReferralCodeMethods if acts_as_subscriber_options[:referral_code_enabled]
        end
      end

      module SingletonReferralCodeMethods
        
        def setup_referral_codes!
          #do this in case the user has not added acts_as_subscriber yet....
          find(:all, :select => 'id').each do |u| 
            u.setup_referral_code
            u.save_without_validation
          end
        end
        
        def generate_referral_code(token_size=7)
          require 'rails_generator/secret_key_generator'
          token = Freemium.referral_code_prefix + Rails::SecretKeyGenerator.new(Time.now.to_i).generate_secret
          token[0..token_size]
        end
      end
      
      module InstanceReferralCodeMethods
        #force referral_code to start with 'ref' so we can differentiate between a coupon and a referral code..
        #allows ability to combine coupon and referral code into one field...easier for users.
        def setup_referral_code
          return true unless self.send(acts_as_subscriber_options[:get_referral_code]).blank?
          require 'rails_generator/secret_key_generator'
          init_token_size = 7
          token = self.class.generate_referral_code(init_token_size)
          # eval("self.#{acts_as_subscriber_options[:set_referral_code]} token")
          self.send(acts_as_subscriber_options[:set_referral_code], token)
          counter = 0
          # finder_class = [self.class].detect { |klass| !klass.abstract_class? }
          # conditions = ["referral_code = ?", self.send(acts_as_subscriber_options[:get_referral_code])]
      
          #hmmm...what do we do if we can't find a unique token?
          
          # u = eval("#{acts_as_subscriber_options[:find_referral_code]} '#{code}'") rescue nil
          # eval("#{acts_as_subscriber_options[:find_referral_code]} '#{code}'")
          while counter < 10 && (eval("#{acts_as_subscriber_options[:find_referral_code]} '#{self.send(acts_as_subscriber_options[:get_referral_code])}'").blank?)
          # while counter < 10 && (finder_class.find(:first, :select => 1, :conditions => conditions))
            token = self.class.generate_referral_code(init_token_size + counter)
            self.send(acts_as_subscriber_options[:set_referral_code], token)
            counter += 1
          end
        end        
      end
      
      module InstanceMethods
        
        def setup_subscription(plan)
          build_subscription( :subscription_plan_id => (plan.is_a?(FreemiumSubscriptionPlan) ? plan.id : plan))
        end
        
        #TODO: it is vague and not defined that this will fail if subscription is not defined!
        #this is not really a good idea... the reason to do it is if you 
        def setup_coupon_referral_code(code, error_field=:base)
          prep_coupon_referral_code(code)
          return true
        rescue ReferralNotAppliedException => e
          errors.add(error_field, e.message)
          return false
        rescue CouponNotAppliedException => e
          errors.add(error_field, e.message)
          return false
        end
        
        #TODO: it is vague and not defined that this will fail if subscription is not defined!
        def apply_coupon_referral_code!(code)
          transaction do
            prep_coupon_referral_code(code)
            self.save!
            save_referring_user!
          end
        end
        
        
        private 
        
        def prep_coupon_referral_code(code)
          return false if subscription.blank?
          if code.start_with?(Freemium.referral_code_prefix)
            #lets check referrals

            #is there a better way to check this?
            
            u = eval("#{acts_as_subscriber_options[:find_referral_code]} '#{code}'") rescue nil
            if u.blank?
              raise ReferralNotAppliedException, "The referral key '#{code}' could not be found."
              # errors.add_to_base("The referral key '#{code}' could not be found.")
              # return false 
            end
            
            #you cannot apply your own referral code on yourself!  nice try....
            if u == self
              raise ReferralNotAppliedException, "You cannot apply your own referral code for yourself.  Try again!"
              # errors.add_to_base("You cannot apply your own referral code for yourself.  Try again!") 
              # return false;
            end

            if acts_as_subscriber_options[:disable_referral_when_method] && self.send(acts_as_subscriber_options[:disable_referral_when_method])
              raise ReferralNotAppliedException, "You can no longer add a referral to your account."
              # errors.add_to_base("You can no longer add a referral to your account.");
              # return false;
            end

            #lets make sure they haven't used it already....
            subscription.coupon_referrals.count(:conditions => {:referring_user_id => u.id}) > 0
            if subscription.coupon_referrals.count(:conditions => {:referring_user_id => u.id}) > 0
              raise ReferralNotAppliedException, "You have already used this referral code."
              # errors.add_to_base("You have already used this referral code.") 
              # return false;
            end

            #we need to apply free days to the user who is using the code AND the user it is coming from.
            
            #apply to the subscription o the current user
            subscription.coupon_referrals.build(:referring_user_id => u.id, :free_days => Freemium.referral_days_for_applied_user)
            
            #apply to the subscription of the referring user
            unless u.subscription.blank?
              #should never have a blank subscription, but just in 
              @referring_user = u
              u.subscription.coupon_referrals.build(:referring_user_id => u.id, :free_days => Freemium.referral_days_for_referred_user)
            end
          else
            c = Coupon.find_by_coupon_code(code)
            if c.blank?
              raise CouponNotAppliedException, "The coupon code '#{code}' could not be found."
              # errors.add_to_base("The coupon code '#{code}' could not be found.")
              # return false 
            end
            
            #make sure it hasn't been applied before
            if subscription.coupon_referrals.count(:conditions => {:coupon_id => c.id}) > 0
              raise CouponNotAppliedException, "You have already used this coupon code."
              # errors.add_to_base("You have already used this coupon code.") 
              # return false;
            end
            #other checks like usage limit, expired, etc
            
            subscription.coupon_referrals.build(:coupon_id => c.id, :free_days => c.span_num_days)
          end          
        end
        
        def save_referring_user!
          return if @referring_user.blank?
          @referring_user.save!
        end
        
        def handle_coupon!
          return true if @coupon.blank?
          success = setup_coupon_referral_code(@coupon, :coupon)
          #do we REALLY want to put this this deep within the process?
          raise ActiveRecord::Rollback unless success
        end
        
      end



    end
  end

end