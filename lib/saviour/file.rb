require 'securerandom'

module Saviour
  class File
    class SourceFilenameExtractor
      def initialize(source)
        @source = source
      end

      def detected_filename
        original_filename || path_filename
      end

      def original_filename
        @source.respond_to?(:original_filename) && @source.original_filename.present? && @source.original_filename
      end

      def path_filename
        @source.respond_to?(:path) && @source.path.present? && ::File.basename(@source.path)
      end
    end


    def initialize(uploader_klass, model, attached_as, version = nil)
      @uploader_klass, @model, @attached_as = uploader_klass, model, attached_as
      @version = version

      @persisted = !!persisted_path
      @source_was = @source = nil
    end

    def exists?
      persisted? && Config.storage.exists?(persisted_path)
    end

    def read
      persisted? && exists? && Config.storage.read(persisted_path)
    end

    def delete
      persisted? && exists? && Config.storage.delete(persisted_path)
    end

    def public_url
      persisted? && Config.storage.public_url(persisted_path)
    end

    alias_method :url, :public_url

    def assign(object)
      raise(RuntimeError, "must respond to `read`") if object && !object.respond_to?(:read)

      @source_data = nil
      @source = object
      @persisted = !object

      object
    end

    def persisted?
      @persisted
    end

    def changed?
      @source_was != @source
    end

    def filename
      ::File.basename(persisted_path) if persisted?
    end

    def with_copy
      raise "must be persisted" unless persisted?

      Tempfile.open([::File.basename(filename, ".*"), ::File.extname(filename)]) do |file|
        begin
          file.binmode
          file.write(read)
          file.flush
          file.rewind

          yield(file)
        ensure
          file.close
          file.delete
        end
      end
    end

    def filename_to_be_assigned
      changed? ? (SourceFilenameExtractor.new(@source).detected_filename || SecureRandom.hex) : nil
    end

    def write
      raise(RuntimeError, "You must provide a source to read from first") unless @source

      path = uploader.write(source_data, filename_to_be_assigned)
      @source_was = @source
      @persisted = true
      path
    end

    def source_data
      @source_data ||= @source.read
    end

    def blank?
      !@source && !persisted?
    end


    private

    def uploader
      @uploader ||= @uploader_klass.new(version: @version, data: {model: @model, attached_as: @attached_as})
    end

    def persisted_path
      if @model.persisted? || @model.destroyed?
        @model.read_attribute(::Saviour::Model::ColumnNamer.new(@attached_as, @version).name)
      end
    end
  end
end
