module Freemium
  module Gateways
    class Test < Base
      def transactions(options = {})
        options
      end

      def charge(*args)
        args
      end

      def cancel(*args)
        args
      end
      
      def store(*args)
        r = ActionController::TestResponse.new
        r.assigns += args
        r
      end
      
    end
  end
end