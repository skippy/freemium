module Freemium
  
  module Acts
    module Subscriber

      def self.included(base)
        base.extend(ClassMethods)  
      end

      module ClassMethods
        def acts_as_subscriber(options = {})
          get_referral_code_method = options[:get_referral_code]
          set_referral_code_method = options[:get_referral_code]
          find_referral_code_method = options[:find_referral_code]
          if self.column_names.include?('referral_code')
            get_referral_code_method ||= 'referral_code'
            set_referral_code_method ||= 'referral_code='
            find_referral_code_method ||= "#{self.class_name}.find_by_referral_code"
          end
          #TODO: do some cleanup to make sure they are methods?
          referral_code_enabled = !(get_referral_code_method.blank? || set_referral_code_method.blank? || find_referral_code_method.blank?)
          
          write_inheritable_attribute(:acts_as_subscriber_options, {
            :referral_code_enabled => referral_code_enabled,
            :get_referral_code => get_referral_code_method,
            :set_referral_code => set_referral_code_method,
            :find_referral_code => find_referral_code_method
          })          
          class_inheritable_reader :acts_as_subscriber_options
          
          has_one   :subscription,     :class_name => 'Freemium::Subscription',   :dependent => :destroy, :as => :subscriber
          
          if referral_code_enabled
            validates_uniqueness_of get_referral_code_method, :case_sensitive => false, :allow_blank => true
            validates_format_of     get_referral_code_method, :with => /\A#{Freemium.referral_code_prefix}/, :message => "must start with '#{Freemium.referral_code_prefix}'"
          end
          
          include Freemium::Acts::Subscriber::InstanceMethods
          include Freemium::Acts::Subscriber::InstanceReferralCodeMethods if acts_as_subscriber_options[:referral_code_enabled]
          extend Freemium::Acts::Subscriber::SingletonReferralCodeMethods if acts_as_subscriber_options[:referral_code_enabled]
        end
      end

      module SingletonReferralCodeMethods
        
        def setup_referral_codes!
          #do this in case the user has not added acts_as_subscriber yet....
          send(:include, Freemium::Acts::Subscriber::InstanceMethods)
          find(:all, :select => 'id').each{|u| u.reset_referral_code!}
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
        def reset_referral_code!
          require 'rails_generator/secret_key_generator'
          init_token_size = 7
          token = SingletonMethods.generate_referral_code(init_token_size + counter)
          self.send(acts_as_subscriber_options[:set_referral_code], token)
          counter = 0
          finder_class = [self.class].detect { |klass| !klass.abstract_class? }
          conditions = ["referral_code = ?", self.send(acts_as_subscriber_options[:get_referral_code])]
      
          #hmmm...what do we do if we can't find a unique token?
          while counter < 10 && (finder_class.find(:first, :select => 1, :conditions => conditions))
            token = SingletonMethods.generate_referral_code(init_token_size + counter)
            self.send(acts_as_subscriber_options[:set_referral_code], token)
            counter += 1
          end
          self.save_without_validation
        end        
      end
      
      module InstanceMethods
        def applied_coupon_referral_code?(code)
          return false if subscription.blank?
          if code.start_with?(Freemium.referral_code_prefix)

            #lets check referrals
            #TODO: need to make this more flexible.....
            u = User.find_by_referral_code(code) rescue nil
            if u.blank?
              errors.add_to_base("The referral key '#{code}' could not be found.")
              return false 
            end
            
            #you cannot apply your own referral code on yourself!  nice try....
            if u == self
              errors.add_to_base("You cannot apply your own referral code for yourself.  Try again!") 
              return false;
            end
            
            #we do
            if Freemium.referral_allowed_after_signup 
              #lets make sure they haven't used it already....
              subscription.coupon_referrals.count(:conditions => {:referring_user_id => u.id}) > 0
              if subscription.coupon_referrals.count(:conditions => {:referring_user_id => u.id}) > 0
                errors.add_to_base("You have already used this referral code.") 
                return false;
              end
            else #do some sort of signup check.... 
              
            end
            #we need to apply free days to the user who is using the code AND the user it is coming from.
            
            #apply to the subscription o the current user
            subscription.coupon_referrals.create(:referring_user_id => u.id, :free_days => Freemium.referral_days_for_applied_user)
            
            #apply to the subscription of the referring user
            unless u.subscription.blank?
              #should never have a blank subscription, but just in 
              u.subscription.coupon_referrals.create(:referring_user_id => u.id, :free_days => Freemium.referral_days_for_referred_user)
            end
          else
            c = Coupon.find_by_coupon_code(code)
            if c.blank?
              errors.add_to_base("The coupon code '#{code}' could not be found.")
              return false 
            end
            
            #make sure it hasn't been applied before
            if subscription.coupon_referrals.count(:conditions => {:coupon_id => c.id}) > 0
              errors.add_to_base("You have already used this coupon code.") 
              return false;
            end
            subscription.coupon_referrals.create(:coupon_id => c.id, :free_days => c.span_num_days)
          end
        end
      end



    end
  end

end