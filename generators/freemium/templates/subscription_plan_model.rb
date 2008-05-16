class <%= subscription_class_name %>Plan < Freemium::SubscriptionPlan
  set_table_name "<%= subscription_singular_name %>_plans"
  
end