require 'uri'

module Saviour
  class UrlSource
    def initialize(url)
      begin
        @uri = URI(url)
      rescue URI::InvalidURIError
        raise ArgumentError, "'#{url}' is not a valid URI"
      end
    end

    def read
      response = with_retry(3) { Net::HTTP.get_response(@uri) }

      raise("Request to #{@uri} failed after 3 attempts.") unless response.is_a?(Net::HTTPSuccess)
      response.body
    end

    def original_filename
      ::File.basename(@uri.path)
    end

    def path
      @uri.path
    end


    private

    def with_retry(n = 3, &block)
      res = block.call

      if res.is_a?(Net::HTTPSuccess) || n == 0
        res
      else
        with_retry(n - 1, &block)
      end
    end
  end
end
