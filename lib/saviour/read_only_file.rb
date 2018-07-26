module Saviour
  class ReadOnlyFile
    attr_reader :persisted_path

    def initialize(persisted_path)
      @persisted_path = persisted_path
    end

    def exists?
      persisted? && Config.storage.exists?(@persisted_path)
    end

    def read
      return nil unless persisted?
      Config.storage.read(@persisted_path)
    end

    def public_url
      return nil unless persisted?
      Config.storage.public_url(@persisted_path)
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