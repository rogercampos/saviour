require 'open-uri'
require 'uri'

module Saviour
  class UrlWrapper
    def initialize(url)
      @uri = URI(url)
    end

    def read
      open(@uri.to_s).read
    end

    def path
      @uri.path
    end
  end
end