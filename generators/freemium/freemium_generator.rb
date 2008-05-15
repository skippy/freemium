class FreemiumGenerator < Rails::Generator::NamedBase
  
  attr_reader :subscription_class_name,
              :subscription_class_path,
              :subscription_file_name,
              :subscription_plural_name,
              :subscription_singular_name
  
  
  def initialize(runtime_args, runtime_options = {})
  @subscription_class_name = runtime_args.shift || 'subscription'

  base_name, @subscription_class_path, @subscription_file_path, @subscription_class_nesting, @subscription_class_nesting_depth = extract_modules(@subscription_class_name)

  @subscription_class_name_without_nesting, @subscription_file_name, @subscription_plural_name = inflect_names(base_name)
  @subscription_singular_name = @subscription_file_name.singularize
  
  if @subscription_class_nesting.empty?
    @subscription_class_name = @subscription_class_name_without_nesting
  else
    @subscription_class_name = "#{@subscription_class_nesting}::#{@subscription_class_name_without_nesting}"
  end
  
  
    runtime_args.insert(0, 'migrations')
    super
  end

  def manifest
    migration_file_name = "create_#{subscription_file_name.gsub(/\//, '_').pluralize}_and_plans"

    recorded_session = record do |m|
      # m.migration_template "migration.rb", "db/migrate", :migration_file_name => "create_subscription_and_plan"
      m.migration_template 'migration.rb', 'db/migrate', :assigns => {
        :migration_name => "Create#{subscription_class_name.pluralize.gsub(/::/, '')}AndPlans"
      }, :migration_file_name => migration_file_name
      
      
      m.template 'freemium_configs.rb', "config/initializers/freemium.rb"
      m.template 'subscription_model.rb',
                  File.join('app/models',
                            subscription_class_path,
                            "#{subscription_file_name}.rb")
      
    end
    
    puts
    puts ("-" * 70)
    puts "Don't forget to:"
    puts
    puts "  review db/migrate/#{migration_file_name}"
    puts "  then run 'rake db:migrate'"
    puts ("-" * 70)
    
    #need to end with this...
    recorded_session
  end
  
  protected
    # Override with your own usage banner.
    def banner
      "Usage: #{$0} freemium [SubscriptionModelName]"
    end
  
end
