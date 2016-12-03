module Saviour
  class SourceFilenameExtractor
    def initialize(source)
      @source = source
    end

    def detected_filename
      original_filename || path_filename
    end

    def original_filename
      value = @source.original_filename if @source.respond_to?(:original_filename)
      value if !value.nil? && value != ''
    end

    def path_filename
      value = @source.path if @source.respond_to?(:path)
      ::File.basename(value) if !value.nil? && value != ''
    end
  end
end