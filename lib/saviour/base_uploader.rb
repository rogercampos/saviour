require_relative 'uploader/store_dir_extractor'
require_relative 'uploader/processors_runner'

module Saviour
  class BaseUploader
    def initialize(opts = {})
      @data = opts.fetch(:data, {})
    end

    def method_missing(name, *args, &block)
      if @data.key?(name)
        @data[name]
      else
        super
      end
    end

    def respond_to_missing?(name, *)
      @data.key?(name) || super
    end

    def write(contents, filename)
      raise RuntimeError, "Please use `store_dir` before trying to write" unless store_dir

      if Config.processing_enabled
        contents, filename = Uploader::ProcessorsRunner.new(self).run!(contents, filename)
      end

      path = ::File.join(store_dir, filename)
      Config.storage.write(contents, path)
      path
    end

    def store_dir
      @store_dir ||= Uploader::StoreDirExtractor.new(self).store_dir
    end

    class << self
      def store_dirs
        @store_dirs ||= []
      end

      def processors
        @processors ||= []
      end

      def process(name = nil, opts = {}, type = :memory, &block)
        if block_given?
          processors.push(method_or_block: name || block, type: type)
        else
          processors.push(method_or_block: name || block, type: type, opts: opts)
        end
      end

      def process_with_file(name = nil, opts = {}, &block)
        process(name, opts, :file, &block)
      end


      def store_dir(name = nil, &block)
        store_dirs.push(name || block)
      end
    end
  end
end
