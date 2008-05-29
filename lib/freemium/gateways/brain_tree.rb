require 'net/http'
require 'net/https'
module Freemium
  module Gateways
    # = Setup and Configuration
    # In your config/initializers/freemium.rb, configure Freemium to use BrainTree:
    #
    #   Freemium.gateway = Freemium::Gateways::BrainTree.new
    #   Freemium.gateway.username = "my_username"
    #   Freemium.gateway.password = "my_password"
    #
    # Note that if you want to use demo/password credentials when not in production mode, this is the place.
    #
    # = Data Structures
    # All amounts should use the Money class (from eponymous gem).
    # All credit cards should use Freemium::CreditCard class (currently just an alias for ActiveMerchant::Billing::CreditCard).
    # All addresses should use Freemium::Address class.
    #
    # = For Testing
    # The URL does not change. If your account is in test mode, no charges will be processed. Otherwise,
    # configure the username and password to be "demo" and "password", respectively.
    class BrainTree
      URL = 'https://secure.braintreepaymentgateway.com/api/transact.php'
      attr_accessor :username, :password

      # using BrainTree's recurring billing is not possible until I have their reporting API
      #def transactions(options = {}); end

      # Stores a card in SecureVault.
      # possible options:
      #  * :address => Freemium::Address object
      #  * :ip => ip address to log at braintree
      #  * :email => email address to log at braintree
      def store(credit_card, options = {})
        p = Post.new(URL, {
          :username => self.username,
          :password => self.password,
          :customer_vault => "add_customer"
        })
        p.params.merge! params_for_credit_card(credit_card)
        p.params.merge! params_for_address(options[:address])
        p.params.merge! params_for_customer_info(options)
        p.commit
        return p.response
      end

      # Updates a card in SecureVault.
      # possible options:
      #  * :credit_card => Freemium::CreditCard object
      #  * :address => Freemium::Address object
      #  * :ip => ip address to log at braintree
      #  * :email => email address to log at braintree
      def update(vault_id, options = {})
        p = Post.new(URL, {
          :username => self.username,
          :password => self.password,
          :customer_vault => "update_customer",
          :customer_vault_id => vault_id
        })
        p.params.merge! params_for_credit_card(options[:credit_card])
        p.params.merge! params_for_address(options[:address])
        p.params.merge! params_for_customer_info(options)
        p.commit
        return p.response
      end

      # Manually charges a card in SecureVault. Called automatically as part of manual billing process.
      def charge(vault_id, amount, options = {})
        p = Post.new(URL, {
          :username => self.username,
          :password => self.password,
          :customer_vault_id => vault_id,
          :type => 'sale',
          :amount => sprintf("%.2f", amount.cents.to_f / 100)
        })
        p.params.merge! params_for_order_info(options)
        p.params.merge! params_for_customer_info(options)
        
        p.commit
        return Freemium::Transaction.new(:billing_key => vault_id, :amount => amount, :success => p.response.success?)
      end
      
      def authorize(vault_id, amount, options = {})
        p = Post.new(URL, {
          :username => self.username,
          :password => self.password,
          :customer_vault_id => vault_id,
          :type => 'auth',
          :amount => sprintf("%.2f", amount.cents.to_f / 100)
        })
        p.params.merge! params_for_order_info(options)
        p.params.merge! params_for_customer_info(options)
        
        p.commit
        return Freemium::Transaction.new(:billing_key => vault_id, :amount => amount, :success => p.response.success?)
      end
      

      # Removes a card from SecureVault. Called automatically when the subscription expires.
      def cancel(vault_id)
        p = Post.new(URL, {
          :username => self.username,
          :password => self.password,
          :customer_vault => 'delete_customer',
          :customer_vault_id => vault_id
        })
        p.commit
        return p.response
      end

      protected

      def params_for_credit_card(card)
        return {} if card.blank?
        params = {
          :payment => 'creditcard',
          :firstname => card.first_name,
          :lastname => card.last_name,
          :ccnumber => card.number,
          :ccexp => ["%.2i" % card.month, ("%.4i" % card.year)[-2..-1]].join # MMYY,
        }
        params[:cvv] = card.verification_value if card.verification_value?
        params
      end

      def params_for_address(address)
        return {} if address.blank?
        {
          :email => address.email,
          :address1 => address.street,
          :city => address.city,
          :state => address.state, # TODO: two-digit code!
          :zip => address.zip,
          :country => address.country # TODO: two digit code! (ISO-3166)
        }
      end
      
      def params_for_customer_info(options)
        params = {}
        if options.has_key? :email
          params[:email] = options[:email]
        end

        if options.has_key? :ip
          params[:ipaddress] = options[:ip]
        end   
        params     
      end
      
      def params_for_order_info(options)
        params = {}
        if options.has_key? :orderid
          params[:orderid] = options[:order_id].to_s.gsub(/[^\w.]/, '')
        end
        params     
      end

      class Post
        attr_accessor :url
        attr_accessor :params
        attr_reader :response

        def initialize(url, params = {})
          self.url = url
          self.params = params
        end

        def commit
          data = parse(post)
          # from BT API: 1 means approved, 2 means declined, 3 means error
          success = data['response'].to_i == 1
          @response = Freemium::Response.new(success, data)
          @response.billing_key = data['customer_vault_id']
          @response.message = data['responsetext']
          return self
        end

        protected

        # BrainTree returns a body of parameters in GET query format, so convert that into a simple hash.
        def parse(data)
          returning({}) do |results|
            data.split('&').each do |pair|
              key, value = pair.split('=')
              results[key] = value
            end
          end
        end

        # cf. ActiveMerchant's PostsData module.
        def post
          uri   = URI.parse(self.url)

          http = Net::HTTP.new(uri.host, uri.port)
          http.open_timeout = 10
          http.read_timeout = 10
          http.use_ssl      = true
          http.verify_mode  = OpenSSL::SSL::VERIFY_NONE

          data = self.params.collect { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&")
          http.post(uri.request_uri, data).body
        end
      end
    end
  end
end