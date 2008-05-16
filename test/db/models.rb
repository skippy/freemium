class User < ActiveRecord::Base
  has_many :subscriptions, :as => :subscriptable
end