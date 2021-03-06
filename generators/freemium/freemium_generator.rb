class FreemiumGenerator < Rails::Generator::NamedBase

  default_options :add_referral_col => false,
                  :acts_as_versioned_enabled => false,
                  :acts_as_paranoid_enabled => false

  attr_reader :user_class_name,
              :user_file_path,
              :user_class_nesting,
              :user_class_nesting_depth,
              :user_class_name,
              :user_singular_name,
              :user_plural_name,
              :user_file_name  
  
  def initialize(runtime_args, runtime_options = {})
    runtime_args.insert(0, 'migrations')
    super
  end

  def manifest
    recorded_session = record do |m|
      if options[:add_referral_col]
        base_name, @user_class_name, @user_file_path, @user_class_nesting, @user_class_nesting_depth = extract_modules(options[:add_referral_col])
        @user_class_name_without_nesting, @user_file_name, @user_plural_name = inflect_names(base_name)
        @user_singular_name = @user_file_name.singularize
        
        if @user_class_nesting.empty?
          @user_class_name = @user_class_name_without_nesting
        else
          @user_class_name = "#{@user_class_nesting}::#{@user_class_name_without_nesting}"
        end
      end
      
      begin
        require 'acts_as_versioned'
        options[:acts_as_versioned_enabled] = true
      rescue Exception => e
        options[:acts_as_versioned_enabled] = false
      end

      begin
        require 'caboose/acts/paranoid'
        options[:acts_as_paranoid_enabled] = true
      rescue Exception => e
        options[:acts_as_paranoid_enabled] = false
      end
      
      m.migration_template 'migration.rb', 'db/migrate', :migration_file_name => "create_freemium_migrations"
      
      m.template 'freemium_configs.rb', "config/initializers/freemium.rb"
      m.template 'subscription_mailer.rb', 'app/models/freemium_mailer.rb'
      
      m.directory 'app/views/freemium_mailer'
      %w( admin_report expiration_notice expiration_warning invoice ).each do |action|
        m.file "subscription_mailer/#{action}.rhtml",
                   File.join( 'app/views/freemium_mailer', "#{action}.rhtml")
      end
    end

    puts
    puts ("-" * 70)
    puts "Don't forget to:"
    puts "  review db/migrate/create_freemium_migrations"
    puts "  then add 'acts_as_subscriber' to the model that will the subscriber (User, for example)"
    puts
    if user_class_name.blank?
      puts "  To add referral codes, specify:"
      puts "     acts_as_subscriber :get_referral_code => 'my_referral_token', :set_referral_code => 'my_referral_token=', :find_referral_code => 'User.find_by_my_referral_token' "
      puts "  Then run something like:"
      puts "     User.setup_referral_codes!"
    else
      puts "  WARNING: You asked to have the referral_code column added to the '#{user_class_name}' model."      
    end
    puts
    puts "  It is recommended that you double check the migration."
    puts "  then run 'rake db:migrate'"
    puts
    puts ("-" * 70)

    #need to end with this...
    recorded_session
  end

  protected
  # Override with your own usage banner.
  def banner
    "Usage: #{$0} freemium"
  end

  def add_options!(opt)
    opt.separator ''
    opt.separator 'Options:'    
    opt.on("--add-referral-col=ToUserModel", String,
           "allow the subscription service to work with coupons") { |v| options[:add_referral_col] = v }
    # opt.on("--include-referrals", 
    #        "allow the subscription service to work with user referrals") { |v| options[:include_referrals] = true }
  end


end
