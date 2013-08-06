module Saviour
  class BaseUploader
    extend ActiveSupport::Concern
    include Processors::Digest
    attr_reader :model, :mounted_as

    def initialize(model, mounted_as)
      @model, @mounted_as = model, mounted_as
    end

    def write(contents, filename)
      (self.class.processors || []).each do |processor|
        if processor.respond_to?(:call)
          contents, filename = processor.call(contents, filename)
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

    def store_dir
      raise NotImplementedError, "Please provide a `store_dir` method in #{self.class}"
    end


    class Builder
      attr_reader :processors

      def initialize
        @processors = []
      end

      def run(name = nil, opts = {}, &block)
        if block_given?
          @processors.push(block)
        else
          @processors.push([name, opts])
        end
      end
    end

    class << self
      attr_accessor :processors

      def process(&block)
        builder = Builder.new
        builder.instance_eval(&block)
        self.processors = builder.processors
      end
    end
  end
end
