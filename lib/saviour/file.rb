require 'securerandom'

module Saviour
  class File
    attr_reader :persisted_path
    attr_reader :source

    def initialize(uploader_klass, model, attached_as)
      @uploader_klass, @model, @attached_as = uploader_klass, model, attached_as
      @source_was = @source = nil
    end

    def set_path!(path)
      @persisted_path = path
    end

    def exists?
      persisted? && Config.storage.exists?(@persisted_path)
    end

    def read
      persisted? && Config.storage.read(@persisted_path)
    end

    def delete
      persisted? && Config.storage.delete(@persisted_path)
      @persisted_path = nil
      @source_was = nil
      @source = nil
    end

    def public_url
      persisted? && Config.storage.public_url(@persisted_path)
    end

    def ==(another_file)
      return false unless another_file.is_a?(Saviour::File)
      return false unless another_file.persisted? == persisted?

      if persisted?
        another_file.persisted_path == persisted_path
      else
        another_file.source == @source
      end
    end

    def clone
      return nil unless persisted?

      new_file = Saviour::File.new(@uploader_klass, @model, @attached_as)
      new_file.set_path! @persisted_path
      new_file
    end

    def dup
      new_file = Saviour::File.new(@uploader_klass, @model, @attached_as)

      if persisted?
        new_file.assign(Saviour::StringSource.new(read, filename))
      else
        new_file.assign(Saviour::StringSource.new(source_data, filename_to_be_assigned))
      end

      new_file
    end

    alias_method :url, :public_url

    def assign(object)
      raise(SourceError, "given object to #assign or #<attach_as>= must respond to `read`") if object && !object.respond_to?(:read)

      followers = @model.class.attached_followers_per_leader[@attached_as]
      followers.each { |x| @model.send(x).assign(object) unless @model.send(x).changed? } if followers

      @source_data = nil
      @source = object

      if changed? && @model.respond_to?("#{@attached_as}_will_change!")
        @model.send "#{@attached_as}_will_change!"
      end

      @persisted_path = nil if object

      object
    end

    def persisted?
      !!@persisted_path
    end

    def changed?
      @source_was != @source
    end

    def filename
      ::File.basename(@persisted_path) if persisted?
    end

    def with_copy
      raise CannotCopy, "must be persisted" unless persisted?

      temp_file = Tempfile.new([::File.basename(filename, ".*"), ::File.extname(filename)])

      begin
        Config.storage.read_to_file(@persisted_path, temp_file)

        yield(temp_file)
      ensure
        temp_file.close!
      end
    end

    def filename_to_be_assigned
      changed? ? (SourceFilenameExtractor.new(@source).detected_filename || SecureRandom.hex) : nil
    end

    def __maybe_with_tmpfile(source_type, file)
      return yield if source_type == :stream

      tmpfile = Tempfile.new([::File.basename(file.path, ".*"), ::File.extname(file.path)])
      FileUtils.cp(file.path, tmpfile.path)

      begin
        yield(tmpfile)
      ensure
        tmpfile.close!
      end
    end

    def write(before_write: nil)
      raise(MissingSource, "You must provide a source to read from before trying to write") unless @source

      __maybe_with_tmpfile(source_type, @source) do |tmpfile|
        contents, path = case source_type
                           when :stream
                             uploader._process_as_contents(source_data, filename_to_be_assigned)
                           when :file
                             uploader._process_as_file(tmpfile, filename_to_be_assigned)
                         end
        @source_was = @source

        if path
          before_write.call(path) if before_write

          case source_type
            when :stream
              Config.storage.write(contents, path)
            when :file
              Config.storage.write_from_file(contents, path)
          end

          @persisted_path = path
          path
        end
      end
    end

    def source_type
      if @source.respond_to?(:path)
        :file
      else
        :stream
      end
    end

    def source_data
      @source_data ||= begin
        @source.rewind
        @source.read
      end
    end

    def blank?
      !@source && !persisted?
    end


    private

    def uploader
      @uploader ||= @uploader_klass.new(data: { model: @model, attached_as: @attached_as })
    end
  end
end
