module Saviour
  class S3Storage
    def initialize(conf = {})
      @bucket = conf.delete(:bucket)
      @public_url_prefix = conf.delete(:public_url_prefix)
      @conf = conf
      @overwrite_protection = conf.delete(:overwrite_protection) { true }
      @create_options = conf.delete(:create_options) { {} }
      conf.fetch(:aws_access_key_id) { raise ArgumentError.new("aws_access_key_id is required")}
      conf.fetch(:aws_secret_access_key) { raise ArgumentError.new("aws_secret_access_key is required")}
    end

    def write(contents, path)
      raise(RuntimeError, "The path you're trying to write already exists!") if @overwrite_protection && exists?(path)

      path = sanitize_leading_slash(path)
      directory.files.create({
                                 key: path,
                                 body: contents,
                                 public: true
                             }.merge(@create_options)
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
      raise(RuntimeError, "You must provide a `public_url_prefix`") unless public_url_prefix

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

    def assert_exists(path)
      raise RuntimeError, "File does not exists: #{path}" unless exists?(path)
    end

    def directory
      @directory ||= connection.directories.get(@bucket)
    end

    def connection
      @connection ||= Fog::Storage.new({provider: 'AWS'}.merge(@conf))
    end
  end
end
