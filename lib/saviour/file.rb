require 'securerandom'

module Saviour
  class File
    def initialize(uploader_klass, model, mounted_as)
      @uploader_klass, @model, @mounted_as = uploader_klass, model, mounted_as

      @persisted = !!persisted_path
      @source_was = @source = nil
    end

    def exists?
      persisted? && Config.storage.exists?(persisted_path)
    end

    def read
      persisted? && Config.storage.read(persisted_path)
    end

    def delete
      persisted? && Config.storage.delete(persisted_path)
    end

    def public_uri
      persisted? && Config.storage.public_uri(persisted_path)
    end
    alias_method :url, :public_uri

    def assign(object)
      raise("must respond to `read`") if object && !object.respond_to?(:read)

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
      persisted? && ::File.basename(persisted_path)
    end


    def write
      raise "You must provide a source to read from first" unless @source

      name = @source.respond_to?(:path) ? ::File.basename(@source.path) : SecureRandom.hex
      path = uploader.write(@source.read, name)
      @source_was = @source
      @persisted = true
      path
    end

    # Gives you a local copy of the file that is removed afterwards.
    #
    # 1. Safe: you're guaranteed to receive a copy of the file, not the original, so you can perform
    # any operation to modify that file without worrying. If you want to save the results, just reassign and save.
    #
    # 2. Used for example to perform operations on the file from external binaries, like imagemagick
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


    private

    def uploader
      @uploader ||= @uploader_klass.new(@model, @mounted_as)
    end

    def persisted_path
      (@model.persisted? || @model.destroyed?) && @model.read_attribute(@mounted_as)
    end
  end
end
