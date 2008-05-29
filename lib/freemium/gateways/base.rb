module Freemium
  module Gateways
    class Base #:nodoc:
      # cancels the subscription identified by the given billing key.
      # this might mean removing it from the remote system, or halting the remote
      # recurring billing.
      #
      # should return a Freemium::Response
      def cancel(billing_key)
        raise MethodNotImplemented
      end

      # stores a credit card with the gateway.
      # should return a Freemium::Response
      # possible options:
      #  * :address => Freemium::Address object
      #  * :ip => ip address to log at braintree
      #  * :email => email address to log at braintree
      def store(credit_card, options = {})
        raise MethodNotImplemented
      end

      # updates a credit card in the gateway.
      # should return a Freemium::Response
      # possible options:
      #  * :credit_card => Freemium::CreditCard object
      #  * :address => Freemium::Address object
      #  * :ip => ip address to log at braintree
      #  * :email => email address to log at braintree
      def update(billing_key, options = {})
        raise MethodNotImplemented
      end

      ##
      ## Only needed to support Freemium.billing_recurrence_mode = :gateway
      ##

      # only needed to support an ARB module. otherwise, the manual billing process will
      # take care of processing transaction information as it happens.
      #
      # concrete classes need to support these options:
      #   :billing_key : - only retrieve transactions for this specific billing key
      #   :after :       - only retrieve transactions after this datetime (non-inclusive)
      #   :before :      - only retrieve transactions before this datetime (non-inclusive)
      #
      # return value should be a collection of Freemium::Transaction objects.
      def transactions(options = {})
        raise MethodNotImplemented
      end

      ##
      ## Only needed to support Freemium.billing_recurrence_mode = :manual
      ##

      # charges money against the given billing key.
      # should return a Freemium::Transaction
      def charge(billing_key, amount, options = {})
        raise MethodNotImplemented
      end

      # authorize a charge against the given billing key.
      # shoulde return a Freemium::Transaction
      def authorize(billing_key, amount)
        raise MethodNotImplemented
      end

    end
  end
end
