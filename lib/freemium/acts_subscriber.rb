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
        
        # adds the following to the subscriber model
        # * <tt>has_one subscription</tt> 
        # * methods <tt>coupon</tt> and <tt>coupon=</tt>
        # 
        #
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
          before_validation :check_coupon
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
            
            # after_save :save_referring_user!
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
          sub_plan_id = plan.is_a?(FreemiumSubscriptionPlan) ? plan.id : plan
          if self.subscription.blank?
            build_subscription(:subscription_plan_id => sub_plan_id)
          else
            self.subscription.subscription_plan_id = sub_plan_id
          end
        end
        
        #TODO: it is vague and not defined that this will fail if subscription is not defined!
        #this is not really a good idea... the reason to do it is if you 
        # def setup_coupon_referral_code(code, error_field=:base)
        #   if validate_coupon_referral_code(code, error_field)
        #     create_coupon_referral_code(code)
        #     return true
        #   end
        #   return false
        # end
        
        #TODO: it is vague and not defined that this will fail if subscription is not defined!
        def apply_coupon_referral_code(code, error_field=:base)
          if validate_coupon_referral_code(code, error_field)
            return create_coupon_referral_code(code)
            # subscription.save
            # save_referring_user!
          end
          return false
        end
        
        
        private 
        
        def validate_coupon_referral_code(code, error_field=:base)
          validate_coupon_referral_code!(code)
          return true
        rescue ReferralNotAppliedException => e
          errors.add(error_field, e.message)
          return false
        rescue CouponNotAppliedException => e
          errors.add(error_field, e.message)
          return false
        end
        
        #validates the validity of the coupon or referral code.
        #all other validity checks, like coupon usage limit, should go here
        def validate_coupon_referral_code!(code)
          return false if subscription.blank?
          if code.start_with?(Freemium.referral_code_prefix)
            #lets check referrals

            u = eval("#{acts_as_subscriber_options[:find_referral_code]} '#{code}'") rescue nil
            if u.blank?
              raise ReferralNotAppliedException, "The referral key '#{code}' could not be found."
            end
            
            #you cannot apply your own referral code on yourself!  nice try....
            if u == self
              raise ReferralNotAppliedException, "You cannot apply your own referral code for yourself.  Try again!"
            end

            if acts_as_subscriber_options[:disable_referral_when_method] && self.send(acts_as_subscriber_options[:disable_referral_when_method])
              raise ReferralNotAppliedException, "You can no longer add a referral code to your account."
            end

            #lets make sure they haven't used it already....
            subscription.coupon_referrals.count(:conditions => {:referring_user_id => u.id}) > 0
            if subscription.coupon_referrals.count(:conditions => {:referring_user_id => u.id}) > 0
              raise ReferralNotAppliedException, "You have already used this referral code."
            end

          else
            c = FreemiumCoupon.find_by_coupon_code(code)
            if c.blank?
              raise CouponNotAppliedException, "The coupon code '#{code}' could not be found."
            end
            
            #make sure it hasn't been applied before
            if subscription.coupon_referrals.count(:conditions => {:coupon_id => c.id}) > 0
              raise CouponNotAppliedException, "You have already used this coupon code."
            end
            #other checks like usage limit, expired, etc
          end
        end
        
        #build the appropriate relationship.  Assums that validations has already been run.
        def create_coupon_referral_code(code)
          return false if subscription.blank?
          if code.start_with?(Freemium.referral_code_prefix)            
            #apply to the subscription o the current user
            u = eval("#{acts_as_subscriber_options[:find_referral_code]} '#{code}'") rescue nil
            return false if u.blank?
            subscription.coupon_referrals.create(:referring_user_id => u.id, :free_days => Freemium.referral_days_for_applied_user)
            #apply to the subscription of the referring user
            unless u.subscription.blank?
              #should never have a blank subscription, but just in 
              @referring_user = u
              u.subscription.coupon_referrals.create(:referring_user_id => self.id, :free_days => Freemium.referral_days_for_referred_user)
            end
          else
            c = FreemiumCoupon.find_by_coupon_code(code)
            if c
              #assume validation that this exists and is valid
              cr = subscription.coupon_referrals.create(:coupon_id => c.id, :free_days => c.span_num_days)
            end
          end          
        end
        
        #need to make sure that if a referrer code was passed in, that the person who's code it is also
        #gets a row in coupon_referrals.... so making sure it is persisted.
        # def save_referring_user!
        #   return if @referring_user.blank?
        #   @referring_user.subscription.save!
        #   @referring_user = nil #so we don't call it multiple times...
        # end
        
        #NOTE: 'check_coupon' and 'handle_coupon!' are a bit odd in how they are structured.
        # this is to work around a few rails bugs
        # 1) when calling save, it starts at the children and works its way to the parent,
        #    instead of the other way around.  This means that if a child depends upon a parent_id
        #    being set, it won't be, and things will fail
        # 2) the other idea was to have handle_coupon! be called on after_save and raise a Rollback exception
        #    if it is invalid...but this wasn't being bubbled up correctly.  If the save is wrapped with a 
        #    transaction, this exception will be swallowed by the one wrapping the save, but two transactions
        #    are used with only the first (the outer wrapping one) actually having a db transaction.  the inner
        #    one will swallow the exception, where it doesn't really matter, and not bubble it up to the next one,
        #    which is where the db transaction occured.
        def check_coupon
          return true if @coupon.blank?
          validate_coupon_referral_code(@coupon, :coupon)
        end
                
        def handle_coupon!
          return true if @coupon.blank?
          create_coupon_referral_code(@coupon)
          # subscription.save
          # save_referring_user!
          # success = setup_coupon_referral_code(@coupon, :coupon)
          # #do we REALLY want to put this this deep within the process?
          # #TODO: IF there is a transaction on top of the after_save transaction, this will not bubble up.
          # #bug in rails 2.0.2 where the first transaction swallows this, even if it was 
          # # not an open transaction.... 
          # raise ActiveRecord::Rollback unless success
        end
        
      end



    end
  end

end