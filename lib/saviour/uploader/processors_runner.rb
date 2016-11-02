module Saviour
  module Uploader
    class ProcessorsRunner
      attr_writer :file
      attr_accessor :contents
      attr_accessor :filename

      def initialize(uploader, version_name)
        @uploader, @version_name = uploader, version_name
      end

      def matching_processors
        @uploader.class.processors.select do |processor|
          !processor[:element].versioned? || processor[:element].version == @version_name
        end
      end

      def file
        @file ||= Tempfile.new([SecureRandom.hex, ::File.extname(filename)]).tap { |x| x.binmode }
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
          file.rewind
          self.contents = ::File.read(file)
        end

        file.delete

        [contents, filename]
      end
    end
  end
end