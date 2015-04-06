module Saviour
  class StringSource
    def initialize(value, filename = nil)
      @value, @filename = value, filename
    end

    def read
      @value
    end

    def original_filename
      @filename
    end
  end
end