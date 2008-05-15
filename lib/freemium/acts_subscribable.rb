module Freemium
  
  module Acts
    module Subscribable

      def self.included(base)
        base.extend(ClassMethods)  
      end

      module ClassMethods
        def acts_as_subscribable(options = {})
          subscription_model = options[:subscribable] || :subscription
          # write_inheritable_attribute(:acts_as_taggable_options, {
          #   :tagged_type => ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s,
          #   :from => options[:from],
          #   :from_id => "#{options[:from]}_id"
          # })
          # 
          # class_inheritable_reader :acts_as_taggable_options
          # 
          # has_many :tags, :as => :tagged, :dependent => :destroy

          has_one subscription_model, :dependent => :destroy
          
          validates_uniqueness_of :referral_key, :case_sensitive => false, :allow_blank => true


          include Freemium::Acts::Subscribable::InstanceMethods
          extend Freemium::Acts::Subscribable::SingletonMethods
        end
      end

      module SingletonMethods
        
        def setup_referral_keys!
          #do this in case the user has not added acts_as_subscribable yet....
          send(:include, Freemium::Acts::Subscribable::InstanceMethods)
          find(:all, :select => 'id').each{|u| u.reset_referral_key!}
        end
        
      end

      module InstanceMethods
        
        def reset_referral_key!
          require 'rails_generator/secret_key_generator'
          init_token_size = 6
          token = Rails::SecretKeyGenerator.new(Time.now.to_i).generate_secret
          self[:referral_key] = token[1..init_token_size]
          counter = 0
          finder_class = [self.class].detect { |klass| !klass.abstract_class? }
          conditions = ["referral_key = ?", self[:referral_key]]

          #hmmm...what do we do if we can't find a unique token?
          while counter < 10 && (finder_class.find(:first, :select => 1, :conditions => conditions))
            token = Rails::SecretKeyGenerator.new(Time.now.to_i).generate_secret
            self[:referral_key] = token[0..(init_token_size + counter)]
            counter += 1
          end
          self.save_without_validation
        end
        
      end



    end
  end

end