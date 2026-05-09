module Chronicle
  class ValidationError < BaseError
    def initialize(message = 'Validation failed')
      super(message, 422)
    end
  end
end
