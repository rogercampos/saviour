module Saviour
  class ReadOnlyFile
    attr_reader :persisted_path

    def initialize(persisted_path, uploader_klass)
      @persisted_path = persisted_path
      @uploader_klass = uploader_klass
    end

    def exists?
      persisted? && @uploader_klass.storage.exists?(@persisted_path)
    end

    def read
      return nil unless persisted?
      @uploader_klass.storage.read(@persisted_path)
    end

    def public_url
      return nil unless persisted?
      @uploader_klass.storage.public_url(@persisted_path)
    end
    alias_method :url, :public_url

    def ==(another_file)
      return false unless another_file.is_a?(Saviour::File) || another_file.is_a?(ReadOnlyFile)
      return false unless another_file.persisted?

      another_file.persisted_path == persisted_path
    end

    def persisted?
      true
    end
  end
end
