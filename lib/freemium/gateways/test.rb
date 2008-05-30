module Freemium
  module Gateways
    class Test < Base
      def transactions(options = {})
        options
      end

      def charge(billing_key, amount, options = {})
        options
      end

      def cancel(billing_key)
        billing_key
      end
      
      def store(credit_card, options = {})
        p = Post.new('test.host')
        p.response_body = options.collect{|k,v| "#{k}=#{v}"}.join("&"){|k,v| }
        p.commit
        return p.response
      end
      
    end
    
    class Base
      #open it up to overload the post method
      class Post
        attr_accessor :response_body
        def commit
          data = parse(post)
          # from BT API: 1 means approved, 2 means declined, 3 means error
          success = data['response'].blank? ? true : data['response'].to_i == 1
          @response = Freemium::Response.new(success, data)
          @response.billing_key = data.delete('billing_key') ||'test_billing_key'
          @response.message = data.delete('response_msg') || 'test response msg'
          return self
        end


        protected
        # cf. ActiveMerchant's PostsData module.
        def post
          self.response_body || ""
        end
      end
      
    end
    
    
  end
end