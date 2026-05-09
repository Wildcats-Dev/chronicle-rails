module Chronicle
  class BadRequestError < BaseError
    def initialize(message = 'Bad Request')
      super(message, 400)
    end
  end
end
