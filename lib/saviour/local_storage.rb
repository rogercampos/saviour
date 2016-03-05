require 'fileutils'

module Saviour
  class LocalStorage
    def initialize(opts = {})
      @local_prefix = opts[:local_prefix]
      @public_url_prefix = opts[:public_url_prefix]
    end

    def write(contents, path)
      dir = ::File.dirname(real_path(path))
      FileUtils.mkdir_p(dir) unless ::File.directory?(dir)

      ::File.open(real_path(path), "w") do |f|
        f.binmode
        f.write(contents)
      end
    end

    def read(path)
      assert_exists(path)
      ::File.open(real_path(path)).read
    end

    def delete(path)
      assert_exists(path)
      ::File.delete(real_path(path))
      ensure_removed_empty_dir(path)
    end

    def exists?(path)
      ::File.file?(real_path(path))
    end

    def public_url(path)
      raise(RuntimeError, "You must provide a `public_url_prefix`") unless public_url_prefix
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

    def real_path(path)
      @local_prefix ? ::File.join(@local_prefix, path) : path
    end

    def assert_exists(path)
      raise(RuntimeError, "File does not exists: #{path}") unless ::File.file?(real_path(path))
    end

    def ensure_removed_empty_dir(path)
      basedir = ::File.dirname(path)
      return if basedir == "."

      while basedir != "/" && Dir.entries(real_path(basedir)) == [".", ".."]
        Dir.rmdir(real_path(basedir))
        basedir = ::File.dirname(basedir)
      end
    end
  end
end
