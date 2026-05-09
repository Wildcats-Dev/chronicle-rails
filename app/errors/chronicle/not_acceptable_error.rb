module Chronicle
  class NotAcceptableError < BaseError
    def initialize(message = 'Request not acceptable')
      super(message, 406)
    end
  end
end
