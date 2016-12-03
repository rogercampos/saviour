module Saviour
  class Config
    class NotImplemented
      def method_missing(*)
        raise(RuntimeError, "You need to provide a storage! Set Saviour::Config.storage = xxx")
      end
    end

    class << self
      def processing_enabled
        Thread.current["Saviour::Config"] ||= {}
        Thread.current["Saviour::Config"][:processing_enabled] || true
      end

      def processing_enabled=(value)
        Thread.current["Saviour::Config"] ||= {}
        Thread.current["Saviour::Config"][:processing_enabled] = value
      end

      def storage
        Thread.current["Saviour::Config"] ||= {}
        Thread.current["Saviour::Config"][:storage] || Thread.main["Saviour::Config"][:storage] || NotImplemented.new
      end

      def storage=(value)
        Thread.current["Saviour::Config"] ||= {}
        Thread.current["Saviour::Config"][:storage] = value
      end
    end
  end
end