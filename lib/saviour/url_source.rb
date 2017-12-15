require 'uri'
require 'net/http'

module Saviour
  class UrlSource
    TooManyRedirects = Class.new(StandardError)
    InvalidUrl = Class.new(StandardError)
    ConnectionFailed = Class.new(StandardError)

    MAX_REDIRECTS = 10

    def initialize(url)
      @uri = wrap_uri_string(url)
    end

    def read(*args)
      stringio.read(*args)
    end

    def rewind
      stringio.rewind
    end

    def original_filename
      ::File.basename(@uri.path)
    end


    private

    def stringio
      @stringio ||= StringIO.new(raw_data)
    end

    def raw_data
      @raw_data ||= with_retry(3) { resolve(@uri) }
    end

    def resolve(uri, max_redirects = MAX_REDIRECTS)
      raise TooManyRedirects, "Max number of allowed redirects reached (#{MAX_REDIRECTS}) when resolving #{uri}" if max_redirects == 0

      response = Net::HTTP.get_response(uri)

      case response
        when Net::HTTPSuccess
          response.body
        when Net::HTTPRedirection
          resolve(wrap_uri_string(response['location']), max_redirects - 1)
        else
          false
      end
    end

    def wrap_uri_string(url)
      begin
        URI(url)
      rescue URI::InvalidURIError
        raise InvalidUrl, "'#{url}' is not a valid URI"
      end
    end

    def with_retry(n = 3, &block)
      raise(ConnectionFailed, "Connection to #{@uri} failed after 3 attempts.") if n == 0

      block.call || with_retry(n - 1, &block)
    end
  end
end
