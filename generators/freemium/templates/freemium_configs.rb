# Sample configuration, but this will get you bootstrapped and going with BrainTree
# TODO:
#  - information on where to register...
#  - setting up production passwords...
#  - better way to do production/test changes?

Freemium.gateway = Freemium::Gateways::BrainTree.new
Freemium.gateway.username = "demo"
Freemium.gateway.password = "password"

if RAILS_ENV == 'production'
  #put your production password information here....
  Freemium.gateway.username = "demo"
  Freemium.gateway.password = "password"
elsif RAILS_ENV == 'test'
  #prevents you from calling BrainTree during your tests
  Freemium.gateway = Freemium::Gateways::Test.new  
end
