module Chronicle
  class ForbiddenError < BaseError
    def initialize(message = 'Unauthorized')
      super(message, 403)
    end
  end
end
