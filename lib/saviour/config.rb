module Saviour
  class Config
    class << self
      def storage
        @storage || raise(RuntimeError, "You need to provide a storage! Set Saviour::Config.storage = xxx")
      end

      def storage=(value)
        @storage = value
      end
    end
  end
end