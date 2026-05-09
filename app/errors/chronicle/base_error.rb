module Chronicle
  class BaseError < StandardError
    attr_reader :status_code

    def initialize(message = nil, status_code = 400)
      super(message)
      @status_code = status_code
    end
  end
end
