require 'thread'

module Saviour
  class Config
    class NotImplemented
      def method_missing(*)
        raise(RuntimeError, "You need to provide a storage! Set Saviour::Config.storage = xxx")
      end
    end

    @semaphore = Mutex.new

    class << self
      def processing_enabled
        Thread.current.thread_variable_set("Saviour::Config", {}) unless Thread.current.thread_variable_get("Saviour::Config")
        Thread.current.thread_variable_get("Saviour::Config")[:processing_enabled] || true
      end

      def processing_enabled=(value)
        Thread.current.thread_variable_set("Saviour::Config", {}) unless Thread.current.thread_variable_get("Saviour::Config")
        Thread.current.thread_variable_get("Saviour::Config")[:processing_enabled] = value
      end

      def storage
        @semaphore.synchronize do
          Thread.current.thread_variable_set("Saviour::Config", {}) unless Thread.current.thread_variable_get("Saviour::Config")
          Thread.current.thread_variable_get("Saviour::Config")[:storage] || (Thread.main.thread_variable_get("Saviour::Config") && Thread.main.thread_variable_get("Saviour::Config")[:storage]) || NotImplemented.new
        end
      end

      def storage=(value)
        @semaphore.synchronize do
          Thread.current.thread_variable_set("Saviour::Config", {}) unless Thread.current.thread_variable_get("Saviour::Config")
          Thread.current.thread_variable_get("Saviour::Config")[:storage] = value

          if Thread.main.thread_variable_get("Saviour::Config").nil?
            Thread.main.thread_variable_set("Saviour::Config", {})
            Thread.main.thread_variable_get("Saviour::Config")[:storage] = value
          end
        end
      end
    end
  end
end