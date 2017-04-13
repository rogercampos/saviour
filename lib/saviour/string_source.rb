module Saviour
  class StringSource
    def initialize(value, filename = nil)
      @value = StringIO.new(value)
      @filename = filename
    end

    def read(*args)
      @value.read(*args)
    end

    def rewind
      @value.rewind
    end

    def original_filename
      @filename
    end
  end
end