module Chronicle
  class NotFoundError < BaseError
    def initialize(message = 'Resource not found')
      super(message, 404)
    end
  end
end
