require_relative 'uploader/store_dir_extractor'
require_relative 'uploader/processors_runner'

module Saviour
  class BaseUploader
    def initialize(opts = {})
      @data = opts.fetch(:data, {})
      @stash = {}
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

    def _process_as_contents(contents, filename)
      raise ConfigurationError, "Please use `store_dir` in the uploader" unless store_dir

      catch(:halt_process) do
        if Config.processing_enabled
          contents, filename = Uploader::ProcessorsRunner.new(self).run!(contents, filename)
        end

        path = ::File.join(store_dir, filename)

        [contents, path]
      end
    end

    def _process_as_file(file, filename)
      raise ConfigurationError, "Please use `store_dir` in the uploader" unless store_dir

      catch(:halt_process) do
        if Config.processing_enabled
          file, filename = Uploader::ProcessorsRunner.new(self).run_as_file!(file, filename)
        end

        path = ::File.join(store_dir, filename)

        [file, path]
      end
    end

    def halt_process
      throw(:halt_process)
    end

    def stash(hash)
      @stash.deep_merge!(hash)
    end

    def stashed
      @stash
    end

    def store_dir
      @store_dir ||= Uploader::StoreDirExtractor.new(self).store_dir
    end

    def storage
      self.class.storage
    end

    class << self
      def store_dirs
        @store_dirs ||= []
      end

      def processors
        @processors ||= []
      end

      def storage
        @storage ||= Config.storage

        @storage.respond_to?(:call) ? @storage.call : @storage
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

      def with_storage(storage)
        @storage = storage
      end

      def after_upload(&block)
        after_upload_hooks.push(block)
      end

      def after_upload_hooks
        @after_upload ||= []
      end
    end
  end
end
