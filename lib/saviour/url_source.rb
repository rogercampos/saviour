require 'uri'

module Saviour
  class UrlSource
    MAX_REDIRECTS = 10

    def initialize(url)
      @uri = wrap_uri_string(url)
    end

    def read
      with_retry(3) { resolve(@uri) }
    end

    def original_filename
      ::File.basename(@uri.path)
    end

    def path
      @uri.path
    end


    private

    def resolve(uri, max_redirects = MAX_REDIRECTS)
      raise RuntimeError, "Max number of allowed redirects reached (#{MAX_REDIRECTS}) when resolving #{@uri}" if max_redirects == 0

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
        raise ArgumentError, "'#{url}' is not a valid URI"
      end
    end

    def with_retry(n = 3, &block)
      raise("Connection to #{@uri} failed after 3 attempts.") if n == 0

      block.call || with_retry(n - 1, &block)
    end
  end
end
