module Chronicle
  class AuthenticationError < BaseError
    def initialize(message = 'Request not acceptable')
      super(message, 401)
    end
  end
end
