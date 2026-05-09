require 'chronicle/version'
require 'chronicle/configuration'
require 'chronicle/util'
require 'chronicle/engine'

module Chronicle
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def config
      configuration
    end
  end
end
