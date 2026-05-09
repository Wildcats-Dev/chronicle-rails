module Chronicle
  class ResourceBusyError < BaseError
    def initialize(message = 'Resource busy')
      super(message, 409)
    end
  end
end
