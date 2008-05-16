# depends on the Money gem
begin
  require 'money'
rescue LoadError
  puts "Freemium depends on the money gem: http://rubyforge.org/projects/money/"
  puts "maybe: gem install money"
end 

# and the ActiveMerchant CreditCard object (vendor'd)
Dependencies.load_paths << File.expand_path(File.join(File.dirname(__FILE__), 'vendor', 'active_merchant', 'lib'))

require 'freemium'
require 'freemium/acts_subscribable'

ActiveRecord::Base.class_eval do
  include Freemium::Acts::Subscribable
end
