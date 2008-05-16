# depends on the Money gem
require 'money'
# and the ActiveMerchant CreditCard object (vendor'd)
Dependencies.load_paths << File.expand_path(File.join(File.dirname(__FILE__), 'vendor', 'active_merchant', 'lib'))

require 'freemium'
require 'freemium/subscription'
require 'freemium/acts_billable'

ActiveRecord::Base.class_eval do
  include Freemium::Acts::Billable
end
