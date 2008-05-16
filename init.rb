# depends on the Money gem
require 'money'
# and the ActiveMerchant CreditCard object (vendor'd)
Dependencies.load_paths << File.expand_path(File.join(File.dirname(__FILE__), 'vendor', 'active_merchant', 'lib'))

require 'freemium'
require 'freemium/acts_subscribable'

ActiveRecord::Base.class_eval do
  include Freemium::Acts::Subscriptable
end
