require "active_support/core_ext/module/attribute_accessors"
require 'action_dispatch/middleware/session/abstract_store'

module ActionDispatch
  module Session
    class AbstractSecureStore < Rack::Session::Abstract::PersistedSecure
      include Compatibility
      include StaleSessionCheck
      include SessionObject

      def generate_sid
        Rack::Session::SessionId.new(super)
      end

      private
      def set_cookie(request, response, cookie)
        request.cookie_jar[key] = cookie
      end
    end
  end
end if Rails::VERSION::STRING < '5.2.0' # AbstractSecureStore was added in Rails 5.2