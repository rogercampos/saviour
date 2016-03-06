require_relative 'uploader/element'
require_relative 'uploader/store_dir_extractor'
require_relative 'uploader/processors_runner'

module Saviour
  class BaseUploader
    attr_reader :version_name

    def initialize(opts = {})
      @version_name = opts[:version]
      @data = opts.fetch(:data, {})
    end

    def method_missing(name, *args, &block)
      if @data.key?(name)
        @data[name]
      else
        super
      end
    end

    def respond_to?(name, *)
      @data.key?(name) || super
    end

    def write(contents, filename)
      store_dir = Uploader::StoreDirExtractor.new(self).store_dir
      raise RuntimeError, "Please use `store_dir` before trying to write" unless store_dir

      contents, filename = Uploader::ProcessorsRunner.new(self, @version_name).run!(contents, filename) if Config.processing_enabled

      path = ::File.join(store_dir, filename)
      Config.storage.write(contents, path)
      path
    end

    class << self
      def store_dirs
        @store_dirs ||= []
      end

      def processors
        @processors ||= []
      end

      def versions
        @versions ||= []
      end

      def process(name = nil, opts = {}, type = :memory, &block)
        element = Uploader::Element.new(@current_version, name || block)

        if block_given?
          processors.push({element: element, type: type})
        else
          processors.push({element: element, type: type, opts: opts})
        end
      end

      def process_with_file(name = nil, opts = {}, &block)
        process(name, opts, :file, &block)
      end


      def store_dir(name = nil, &block)
        element = Uploader::Element.new(@current_version, name || block)
        store_dirs.push(element)
      end

      def version(name, &block)
        versions.push(name)

        if block
          @current_version = name
          instance_eval(&block)
          @current_version = nil
        end
      end
    end
  end
end
