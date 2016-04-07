require 'pagarme'
require "catarse_pagarme/engine"
require "catarse_pagarme/configuration"
require "catarse_pagarme/payment_engine"


module CatarsePagarme
  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
