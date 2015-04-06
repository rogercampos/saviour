module Saviour
  class BaseUploader
    extend ActiveSupport::Concern
    include Processors::Digest

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
      raise RuntimeError, "Please use `store_dir!` before trying to write" unless __store_dir

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

      path = ::File.join(__store_dir, filename)
      Config.storage.write(contents, path)
      path
    end

    def __store_dir
      @__store_dir ||= begin
        valid_store_dir = if self.class.store_dirs.any? { |x| x.versioned? && x.version == @version_name }
                            self.class.store_dirs.select { |x| x.versioned? && x.version == @version_name }.last
                          else
                            self.class.store_dirs.select { |x| !x.versioned? }.last
                          end

        if valid_store_dir
          if valid_store_dir.block?
            instance_eval(&valid_store_dir.method_or_block)
          else
            send(valid_store_dir.method_or_block)
          end
        end
      end
    end


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
