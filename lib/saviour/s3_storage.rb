module Saviour
  class S3Storage
    def initialize(conf = {})
      @bucket = conf.delete(:bucket)
      @public_url_prefix = conf.delete(:public_url_prefix)
      @conf = conf
      assert_directory_exists!
    end

    def write(contents, path)
      path = sanitize_leading_slash(path)
      directory.files.create(
          key: path,
          body: contents,
          public: true
      )
    end

    def read(path)
      path = sanitize_leading_slash(path)
      assert_exists(path)
      directory.files.get(path).body
    end

    def delete(path)
      path = sanitize_leading_slash(path)
      assert_exists(path)
      directory.files.get(path).destroy
    end

    def exists?(path)
      path = sanitize_leading_slash(path)
      !!directory.files.head(path)
    end

    def public_url(path)
      raise "You must provide a `public_url_prefix`" unless public_url_prefix

      path = sanitize_leading_slash(path)
      ::File.join(public_url_prefix, path)
    end


    private

    def public_url_prefix
      if @public_url_prefix.respond_to?(:call)
        @public_url_prefix.call
      else
        @public_url_prefix
      end
    end

    def sanitize_leading_slash(path)
      path.gsub(/\A\/*/, '')
    end

    def assert_directory_exists!
      directory || raise("The bucket #{@bucket} doesn't exists or misconfigured connection.")
    end

    def assert_exists(path)
      raise "File does not exists: #{path}" unless exists?(path)
    end

    def directory
      @directory ||= connection.directories.get(@bucket)
    end

    def connection
      @connection ||= Fog::Storage.new({provider: 'AWS'}.merge(@conf))
    end
  end
end
