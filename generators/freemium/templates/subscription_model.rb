class <%= subscription_class_name %> < Freemium::Subscription
  # Freemium provides a polymorphic Subscription#subscribable association, which doesn't allow for easy joins. 
  # belongs_to :account, :foreign_key => "subscribable_id" 
  
  def testme
    "testme"
  end
end