module Saviour
  module Processors
    module Digest
      def digest_filename(contents, filename, opts = {})
        separator = opts.fetch(:separator, "-")

        digest = ::Digest::MD5.hexdigest(contents)
        extension = ::File.extname(filename)

        new_filename = "#{[::File.basename(filename, ".*"), digest].join(separator)}#{extension}"

        [contents, new_filename]
      end
    end
  end
end