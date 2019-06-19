module Saviour
  class ReadOnlyFile
    attr_reader :persisted_path, :storage

    def initialize(persisted_path, storage)
      @persisted_path = persisted_path
      @storage = storage
    end

    def exists?
      persisted? && @storage.exists?(@persisted_path)
    end

    def read
      return nil unless persisted?
      @storage.read(@persisted_path)
    end

    def public_url
      return nil unless persisted?
      @storage.public_url(@persisted_path)
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
