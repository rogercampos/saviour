module Saviour
  module Config
    extend self

    attr_writer :storage
    def storage
      @storage || raise(RuntimeError, "You need to provide a storage! Set Saviour::Config.storage = xxx")
    end

    attr_accessor :processing_enabled
    @processing_enabled = true
  end
end