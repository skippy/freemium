class FreemiumGenerator < Rails::Generator::NamedBase

  default_options :ignore_coupons => false,
  :include_referrals => false


  def initialize(runtime_args, runtime_options = {})

    runtime_args.insert(0, 'migrations')
    super
  end

  def manifest
    recorded_session = record do |m|
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
    puts
    puts "  review db/migrate/create_freemium_migrations"
    puts "  then run 'rake db:migrate'"
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
