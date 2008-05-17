# Sample configuration, but this will get you bootstrapped with BrainTree
# TODO:
#  - information on where to register...
#  - setting up production passwords...
#  - better way to do production/test changes?

Freemium.gateway = Freemium::Gateways::BrainTree.new
Freemium.gateway.username = "demo"
Freemium.gateway.password = "password"

#If you want Freemium to take care of the billing itself 
#  (ie, handle everything within your app, with recurring payments via cron 
#  or some other batch job)
#  use :manual
#
#if you want to use the gateways recuring payment system
#  use :gateway
Freemium.billing_recurrence_mode = :manual

#the mailer used to send out emails to user
Freemium.mailer = FreemiumMailer

# uncomment to be cc'ed on all freemium emails that go out to the user
# Freemium.admin_report_recipients = %w{admin@site.com}

#the grace period, in days, before Freemium triggers additional mails 
#for the client.  Defaults to 3
Freemium.days_grace = 3

##### SEE Freemium for additional choices

if RAILS_ENV == 'production'
  #put your production password information here....
  Freemium.gateway.username = "demo"
  Freemium.gateway.password = "password"
elsif RAILS_ENV == 'test'
  #prevents you from calling BrainTree during your tests
  Freemium.gateway = Freemium::Gateways::Test.new  
end
