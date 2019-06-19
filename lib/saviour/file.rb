require 'securerandom'

module Saviour
  class File
    attr_reader :persisted_path, :source, :storage

    def initialize(uploader_klass, model, attached_as, persisted_path = nil)
      @uploader_klass, @model, @attached_as = uploader_klass, model, attached_as
      @source_was = @source = nil
      @persisted_path = persisted_path
      @storage = @uploader_klass.storage

      if persisted_path
        @model.instance_variable_set("@__uploader_#{@attached_as}_was", ReadOnlyFile.new(persisted_path, @uploader_klass.storage))
      end
    end

    def exists?
      persisted? && @storage.exists?(@persisted_path)
    end

    def read
      return nil unless persisted?
      @storage.read(@persisted_path)
    end

    def delete
      @persisted_path = nil
      @source_was = nil
      @source = nil
    end

    def public_url
      return nil unless persisted?
      @storage.public_url(@persisted_path)
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
      Saviour::File.new(@uploader_klass, @model, @attached_as, @persisted_path)
    end

    def dup(new_model)
      new_file = Saviour::File.new(@uploader_klass, new_model, @attached_as)

      if persisted?
        new_file.assign(Saviour::StringSource.new(read, filename))
      elsif @source
        new_file.assign(Saviour::StringSource.new(source_data, filename_to_be_assigned))
      end

      new_file
    end

    def reload
      @model.instance_variable_set("@__uploader_#{@attached_as}", nil)
      @model.instance_variable_set("@__uploader_#{@attached_as}_was", nil)
    end

    alias_method :url, :public_url

    def assign(object)
      raise(SourceError, "given object to #assign or #<attach_as>= must respond to `read`") if object && !object.respond_to?(:read)

      followers = @model.class.followers_per_leader_config[@attached_as]

      (followers || []).each do |x|
        attachment = @model.send(x[:attachment])
        attachment.assign(object) unless attachment.changed?
      end

      @source_data = nil
      @source = object

      if changed? && @model.instance_variable_get("@__uploader_#{@attached_as}_was").nil?
        @model.instance_variable_set("@__uploader_#{@attached_as}_was", clone)
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
      temp_file.binmode

      begin
        @storage.read_to_file(@persisted_path, temp_file)

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
      tmpfile.binmode
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
              @storage.write(contents, path)
            when :file
              @storage.write_from_file(contents, path)
          end

          @persisted_path = path
          @model.instance_variable_set("@__uploader_#{@attached_as}_was", ReadOnlyFile.new(persisted_path, @storage))
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
        @source.rewind if @source.respond_to?(:rewind)
        @source.read
      end
    end

    def blank?
      !@source && !persisted?
    end

    def uploader
      @uploader ||= @uploader_klass.new(data: { model: @model, attached_as: @attached_as })
    end
  end
end
