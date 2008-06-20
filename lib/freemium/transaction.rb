module Freemium
  # a temporary model to describe a transaction
  class Transaction
    # the id of the client in the remote system
    attr_accessor :billing_key
    # the amount of the transaction in Money
    attr_accessor :amount
    # if the transaction was a success or not (default is false)
    attr_accessor :success
    #holds the Freemium::Response
    attr_accessor :response

    def initialize(options = {})
      options.each do |(k, v)|
        setter = "#{k}="
        self.send(setter, v) if respond_to? setter
      end
    end

    alias_method :success?, :success

    def to_s
      extra_info = response.blank? ? '' : "Other info: response_code=#{response['response_code']}, orderid=#{response['orderid']}, avsresponse=#{response['avsresponse']}, transactionid=#{response['transactionid']}, responsetext=#{response['responsetext']}, type=#{response['type']}"
      "#{success? ? "billed" : "failed to bill"} key #{billing_key} for #{amount.format}.  #{extra_info}"
    end
  end
end