class FreemiumGenerator < Rails::Generator::NamedBase

  default_options :ignore_coupons => false,
  :include_referrals => false

  attr_reader :user_class_name,
  :user_class_path,
  :user_file_name,
  :user_plural_name,
  :user_singular_name

  # attr_reader :subscription_class_name,
  # :subscription_class_path,
  # :subscription_file_name,
  # :subscription_plural_name,
  # :subscription_singular_name
  # 
  # attr_reader :coupon_class_name,
  # :coupon_class_path,
  # :coupon_file_name,
  # :coupon_plural_name,
  # :coupon_singular_name
  # 
  # attr_reader :user_coupon_class_name,
  # :user_coupon_class_path,
  # :user_coupon_file_name,
  # :user_coupon_plural_name,
  # :user_coupon_singular_name


  def initialize(runtime_args, runtime_options = {})
    @user_class_name = runtime_args.shift  || 'user'
    # @subscription_class_name = runtime_args.shift || 'subscription'
    # @coupon_class_name = runtime_args.shift || 'coupon'
    # 
    # 
    # ### USER model information
    # if @user_class_name
    #   base_name, @user_class_path, @user_file_path, @user_class_nesting, @user_class_nesting_depth = extract_modules(@user_class_name)
    # 
    #   @user_class_name_without_nesting, @user_file_name, @user_plural_name = inflect_names(base_name)
    #   @user_singular_name = @user_file_name.singularize
    # 
    #   if @user_class_nesting.empty?
    #     @user_class_name = @user_class_name_without_nesting
    #   else
    #     @user_class_name = "#{@user_class_nesting}::#{@user_class_name_without_nesting}"
    #   end
    # end
    # 
    # ### SUBSCRIPTION information
    # base_name, @subscription_class_path, @subscription_file_path, @subscription_class_nesting, @subscription_class_nesting_depth = extract_modules(@subscription_class_name)
    # 
    # @subscription_class_name_without_nesting, @subscription_file_name, @subscription_plural_name = inflect_names(base_name)
    # @subscription_singular_name = @subscription_file_name.singularize
    # 
    # if @subscription_class_nesting.empty?
    #   @subscription_class_name = @subscription_class_name_without_nesting
    # else
    #   @subscription_class_name = "#{@subscription_class_nesting}::#{@subscription_class_name_without_nesting}"
    # end
    # 
    # ### COUPON information
    # base_name, @coupon_class_path, @coupon_file_path, @coupon_class_nesting, @coupon_class_nesting_depth = extract_modules(@coupon_class_name)
    # 
    # @coupon_class_name_without_nesting, @coupon_file_name, @coupon_plural_name = inflect_names(base_name)
    # @coupon_singular_name = @coupon_file_name.singularize
    # 
    # if @coupon_class_nesting.empty?
    #   @coupon_class_name = @coupon_class_name_without_nesting
    # else
    #   @coupon_class_name = "#{@coupon_class_nesting}::#{@coupon_class_name_without_nesting}"
    # end
    # 
    # ### USER_COUPON information
    # @user_coupon_class_name = "#{user_class_name}#{coupon_class_name}Referral"
    # base_name, @user_coupon_class_path, @user_coupon_file_path, @user_coupon_class_nesting, @user_coupon_class_nesting_depth = extract_modules(@user_coupon_class_name)
    # 
    # @user_coupon_class_name_without_nesting, @user_coupon_file_name, @user_coupon_plural_name = inflect_names(base_name)
    # @user_coupon_singular_name = @user_coupon_file_name.singularize
    # 
    # if @user_coupon_class_nesting.empty?
    #   @user_coupon_class_name = @user_coupon_class_name_without_nesting
    # else
    #   @user_coupon_class_name = "#{@user_coupon_class_nesting}::#{@user_coupon_class_name_without_nesting}"
    # end
    # 

    #this will cause it to fail if @user_class_name is blank... not sure why!
    runtime_args.insert(0, @user_class_name) if @user_class_name
    super
  end

  def manifest
    # subscription_model_fullpath =         File.join('app/models', subscription_class_path, "#{subscription_file_name}.rb")
    # subscription_plan_model_fullpath =    File.join('app/models', subscription_class_path, "#{subscription_file_name}_plan.rb")
    # coupon_model_fullpath = File.join('app/models', coupon_class_path, "#{coupon_file_name}.rb")
    # user_coupon_referral_model_fullpath = File.join('app/models', coupon_class_path, "#{user_coupon_file_name}.rb")

    recorded_session = record do |m|
      m.migration_template 'migration.rb', 'db/migrate', :migration_file_name => "create_freemium_migrations"
      
      m.template 'freemium_configs.rb', "config/initializers/freemium.rb"

      # m.template 'subscription_model.rb', 'app/models/freemium/subscription.rb'
      # m.template 'subscription_plan_model.rb', 'app/models/freemium/subscription_plan.rb'
      # m.template 'coupon_model.rb', 'app/models/freemium/coupon.rb'
      # m.template 'coupon_referral_model.rb', 'app/models/freemium/coupon_referral.rb'
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
    puts
    puts "  review db/migrate/create_freemium_migrations"
    puts "    WARNING: migrations and model manipulation will occur against the '#{user_class_name}' model"
    puts "  then run 'rake db:migrate'"
    puts "  You will find integration instructions within your model here:"
    # puts "    #{subscription_model_fullpath}"
    puts ("-" * 70)

    #need to end with this...
    recorded_session
  end

  protected
  # Override with your own usage banner.
  # def banner
  #   "Usage: #{$0} freemium UserModelName [SubscriptionModelName] [CouponReferralModelName]"
  # end

  # def add_options!(opt)
  #   opt.separator ''
  #   opt.separator 'Options:'
  #   opt.on("--include-coupons", 
  #          "allow the subscription service to work with coupons") { |v| options[:include_coupons] = v }
  #   opt.on("--include-referrals", 
  #          "allow the subscription service to work with user referrals") { |v| options[:include_referrals] = true }
  # end


end
