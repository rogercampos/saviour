module Saviour
  class Config
    class NotImplemented
      def method_missing(*)
        raise(RuntimeError, "You need to provide a storage! Set Saviour::Config.storage = xxx")
      end
    end

    extend ActiveSupport::PerThreadRegistry

    attr_accessor :storage, :processing_enabled

    self.processing_enabled = true
    self.storage = NotImplemented.new
  end
end