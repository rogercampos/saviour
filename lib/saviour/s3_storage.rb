begin
  require 'aws-sdk-s3'
rescue LoadError
end

require 'marcel'

module Saviour
  class S3Storage
    MissingPublicUrlPrefix = Class.new(StandardError)
    KeyTooLarge = Class.new(StandardError)

    def initialize(conf = {})
      @bucket = conf.delete(:bucket)
      @public_url_prefix = conf.delete(:public_url_prefix)
      @extra_aws_client_options = conf.delete(:aws_client_opts)
      @conf = conf
      @create_options = conf.delete(:create_options) { {} }
      conf.fetch(:aws_access_key_id) { raise(ArgumentError, "aws_access_key_id is required") }
      conf.fetch(:aws_secret_access_key) { raise(ArgumentError, "aws_secret_access_key is required") }
      @region = conf[:region] || raise(ArgumentError, "region is required")
    end

    def write(file_or_contents, path)
      path = sanitize_leading_slash(path)

      # http://docs.aws.amazon.com/AmazonS3/latest/dev/UsingMetadata.html
      if path.bytesize > 1024
        raise(KeyTooLarge, "The key in S3 must be at max 1024 bytes, this key is too big: #{path}")
      end

      mime_type = Marcel::MimeType.for file_or_contents

      # TODO: Use multipart api
      client.put_object(@create_options.merge(
        body: file_or_contents, bucket: @bucket, key: path, content_type: mime_type
      ))
    end

    def write_from_file(file, path)
      file.rewind

      write(file, path)
    end

    def read_to_file(path, dest_file)
      path = sanitize_leading_slash(path)

      dest_file.binmode
      dest_file.rewind
      dest_file.truncate(0)

      client.get_object({ bucket: @bucket, key: path }, target: dest_file)
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      raise FileNotPresent, "Trying to read an unexisting path: #{path}"
    end

    def read(path)
      path = sanitize_leading_slash(path)

      client.get_object(bucket: @bucket, key: path).body.read
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      raise FileNotPresent, "Trying to read an unexisting path: #{path}"
    end

    def delete(path)
      path = sanitize_leading_slash(path)

      client.delete_object(
        bucket: @bucket,
        key: path
      )
    end

    def exists?(path)
      path = sanitize_leading_slash(path)

      !!client.head_object(
        bucket: @bucket,
        key: path
      )
    rescue Aws::S3::Errors::NotFound
      false
    end

    def public_url(path)
      raise(MissingPublicUrlPrefix, "You must provide a `public_url_prefix`") unless public_url_prefix

      path = sanitize_leading_slash(path)
      ::File.join(public_url_prefix, path)
    end

    def cp(source_path, destination_path)
      source_path = sanitize_leading_slash(source_path)
      destination_path = sanitize_leading_slash(destination_path)

      client.copy_object(
        @create_options.merge(
          copy_source: "/#{@bucket}/#{source_path}",
          bucket: @bucket,
          key: destination_path
        )
      )
    rescue Aws::S3::Errors::NoSuchKey
      raise FileNotPresent, "Trying to cp an unexisting path: #{source_path}"
    end

    def mv(source_path, destination_path)
      cp(source_path, destination_path)
      delete(source_path)
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

    def client
      @client ||= Aws::S3::Client.new(
        {
          access_key_id: @conf[:aws_access_key_id],
          secret_access_key: @conf[:aws_secret_access_key],
          region: @region
        }.merge(@extra_aws_client_options || {})
      )
    end
  end
end
