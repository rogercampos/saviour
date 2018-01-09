module Saviour
  module Uploader
    class ProcessorsRunner
      attr_writer :path
      attr_accessor :contents
      attr_accessor :filename

      def initialize(uploader)
        @uploader = uploader
      end

      def matching_processors
        @uploader.class.processors
      end

      def file
        @file ||= Tempfile.new([SecureRandom.hex, ::File.extname(filename)]).tap { |x| x.binmode }
      end

      def run_method_or_block(method_or_block, opts, data)
        if method_or_block.respond_to?(:call)
          @uploader.instance_exec(data, filename, &method_or_block)
        else
          if opts.empty?
            @uploader.send(method_or_block, data, filename)
          else
            @uploader.send(method_or_block, data, filename, opts)
          end
        end
      end

      def advance!(processor, previous_type)
        if processor[:type] != previous_type
          if processor[:type] == :memory
            self.contents = ::File.read(@path)
          else
            file.rewind
            file.truncate(0)
            file.write(contents)
            file.flush
            @path = file.path
          end
        end
      end

      def run_processor(processor)
        method_or_block = processor[:method_or_block]
        opts = processor[:opts]

        if processor[:type] == :memory
          result = run_method_or_block(method_or_block, opts, contents)

          self.contents = result[0]
          self.filename = result[1]

        else
          result = run_method_or_block(method_or_block, opts, @path)

          @path = result[0]
          self.filename = result[1]
        end
      end

      def run!(content_data, initial_filename)
        self.contents = content_data
        self.filename = initial_filename
        previous_type = :memory

        matching_processors.each do |processor|
          advance!(processor, previous_type)

          run_processor(processor)
          previous_type = processor[:type]
        end

        if previous_type == :file
          self.contents = ::File.read(@path)
        end

        file.close! if @file

        [contents, filename]
      end

      def run_as_file!(start_file, initial_filename)
        @contents = nil
        @path = start_file.path
        @filename = initial_filename

        previous_type = :file

        matching_processors.each do |processor|
          advance!(processor, previous_type)

          run_processor(processor)
          previous_type = processor[:type]
        end

        if previous_type == :memory
          ::File.write(start_file.path, contents)
          @path = start_file.path
        end

        file.close! if @file

        [::File.open(@path), filename]
      end
    end
  end
end