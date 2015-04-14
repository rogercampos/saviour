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

    class RunProcessors
      attr_writer :file
      attr_accessor :contents
      attr_accessor :filename

      def initialize(uploader, version_name)
        @uploader, @version_name = uploader, version_name
      end

      def matching_processors
        @uploader.class.processors.select { |processor| !processor[:element].versioned? || processor[:element].version == @version_name }
      end

      def file
        @file ||= Tempfile.new(SecureRandom.hex).tap { |x| x.binmode }
      end

      def run_element(element, opts, data)
        if element.block?
          @uploader.instance_exec(data, filename, &element.method_or_block)
        else
          if opts.empty?
            @uploader.send(element.method_or_block, data, filename)
          else
            @uploader.send(element.method_or_block, data, filename, opts)
          end
        end
      end

      def advance!(processor, previous_type)
        if processor[:type] != previous_type
          if processor[:type] == :memory
            self.contents = ::File.read(file)
          else
            file.rewind
            file.write(contents)
            file.flush
            file.rewind
          end
        end
      end

      def run_processor(processor)
        element = processor[:element]
        opts = processor[:opts]

        if processor[:type] == :memory
          result = run_element(element, opts, contents)

          self.contents = result[0]
          self.filename = result[1]

        else
          file.rewind

          result = run_element(element, opts, file)

          self.file = result[0]
          self.filename = result[1]
        end
      end

      def run!(content_data, name)
        self.contents = content_data
        self.filename = name
        previous_type = :memory

        matching_processors.each do |processor|
          advance!(processor, previous_type)
          run_processor(processor)
          previous_type = processor[:type]
        end

        if previous_type == :file
          file.rewind
          self.contents = ::File.read(file)
        end

        file.delete

        [contents, filename]
      end
    end


    def write(contents, filename)
      store_dir = StoreDirExtractor.new(self).store_dir
      raise RuntimeError, "Please use `store_dir` before trying to write" unless store_dir

      contents, filename = RunProcessors.new(self, @version_name).run!(contents, filename)

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

      def run(name = nil, opts = {}, type = :memory, &block)
        element = Element.new(@current_version, name || block)

        if block_given?
          processors.push({element: element, type: type})
        else
          processors.push({element: element, type: type, opts: opts})
        end
      end

      def run_with_file(name = nil, opts = {}, &block)
        run(name, opts, :file, &block)
      end


      def store_dir(name = nil, &block)
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
