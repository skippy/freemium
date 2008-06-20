module Freemium
  # used to encapsulate the success/failure/details of a response from some gateway.
  # intended to be independent of the details of communication (e.g. Freemium::Gateways::BrainTree::Post).
  class Response
    # a gateway-specific hash of raw data related to the request.
    attr_reader :raw_data
    # may contain a description of the response. should contain an explanation if the response was not a success.
    attr_accessor :message
    # the related billing key, if appropriate
    attr_accessor :billing_key

    cattr_writer :modify_response_msg_proc
    @@cleaned_msg = nil

    def initialize(success, raw_data = {})
      @success, @raw_data = success, raw_data
    end
    
    def cleaned_message
      return @message if @@modify_response_msg_proc.blank?
      @@cleaned_msg ||= @@modify_response_msg_proc.call(self)
    end

    def success?
      @success
    end

    def [](key)
      raw_data[key]
    end
  end
end