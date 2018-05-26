module Chartl
  class ApplicationController < ActionController::Base
    before_action :perform_auth_callback

    class << self
      attr_accessor :auth_callback
    end

    # Allow authentication hookup for the parent app
    def self.set_auth_callback(&block)
      Chartl::ApplicationController.auth_callback = block
    end

    def perform_auth_callback
      if Chartl::ApplicationController.auth_callback
        Chartl::ApplicationController.auth_callback.call(request)
      end
    end
  end
end