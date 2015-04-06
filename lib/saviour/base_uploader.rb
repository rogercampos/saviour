module Saviour
  class BaseUploader
    class Element
      attr_reader :version, :method_or_block

      def initialize(version, method_or_block)
        @version, @method_or_block = version, method_or_block
      end

      def versioned?
        !!@version
      end

      def block?
        @method_or_block.respond_to?(:call)
      end
    end

    class StoreDirExtractor
      def initialize(uploader)
        @uploader = uploader
      end

      def candidate_store_dirs
        @candidate_store_dirs ||= @uploader.class.store_dirs
      end

      def versioned_store_dirs?
        candidate_store_dirs.any? { |x| x.versioned? && x.version == @uploader.version_name }
      end

      def versioned_store_dir
        candidate_store_dirs.select { |x| x.versioned? && x.version == @uploader.version_name }.last if versioned_store_dirs?
      end

      def non_versioned_store_dir
        candidate_store_dirs.select { |x| !x.versioned? }.last
      end

      def store_dir_handler
        @store_dir_handler ||= versioned_store_dir || non_versioned_store_dir
      end

      def store_dir
        @store_dir ||= begin
          if store_dir_handler
            if store_dir_handler.block?
              @uploader.instance_eval(&store_dir_handler.method_or_block)
            else
              @uploader.send(store_dir_handler.method_or_block)
            end
          end
        end
      end
    end

    extend ActiveSupport::Concern
    include Processors::Digest
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

    def respond_to?(name, *args)
      @data.key?(name) || super
    end

    def write(contents, filename)
      store_dir = StoreDirExtractor.new(self).store_dir
      raise RuntimeError, "Please use `store_dir!` before trying to write" unless store_dir

      self.class.processors.select { |element, _| !element.versioned? || element.version == @version_name }.each do |element, opts|
        if element.block?
          contents, filename = instance_exec(contents, filename, &element.method_or_block)
        else
          if opts.empty?
            contents, filename = send(element.method_or_block, contents, filename)
          else
            contents, filename = send(element.method_or_block, contents, filename, opts)
          end
        end
      end

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

      def run(name = nil, opts = {}, &block)
        element = Element.new(@current_version, name || block)
        if block_given?
          processors.push(element)
        else
          processors.push([element, opts])
        end
      end

      def store_dir!(name = nil, &block)
        element = Element.new(@current_version, name || block)
        store_dirs.push(element)
      end

      def version(name, &block)
        @current_version = name
        instance_eval(&block)
        @current_version = nil
      end
    end
  end
end
