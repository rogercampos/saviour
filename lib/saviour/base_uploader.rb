module Saviour
  class BaseUploader
    extend ActiveSupport::Concern
    include Processors::Digest

    def initialize(data = {})
      @data = data
    end

    def method_missing(name, *args, &block)
      if @data.key?(name)
        @data[name]
      else
        super
      end
    end

    def respond_to?(name, *args)
      @data.key?(name) || super
    end

    def write(contents, filename)
      if self.class.store_dir
        store_dir = if self.class.store_dir.respond_to?(:call)
                      instance_eval(&self.class.store_dir)
                    else
                      send(self.class.store_dir)
                    end
      else
        raise RuntimeError, "Please use `store_dir` before trying to write"
      end

      (self.class.processors || []).each do |processor|
        if processor.respond_to?(:call)
          contents, filename = instance_exec(contents, filename, &processor)
        else
          if processor[1].empty?
            contents, filename = send(processor[0], contents, filename)
          else
            contents, filename = send(processor[0], contents, filename, processor[1])
          end
        end
      end

      path = ::File.join(store_dir, filename)
      Config.storage.write(contents, path)
      path
    end


    class << self
      def store_dir
        @store_dir
      end

      def processors
        @processors ||= []
      end

      def run(name = nil, opts = {}, &block)
        if block_given?
          processors.push(block)
        else
          processors.push([name, opts])
        end
      end

      def store_dir!(name = nil, &block)
        if block_given?
          @store_dir = block
        else
          @store_dir = name
        end
      end
    end
  end
end
