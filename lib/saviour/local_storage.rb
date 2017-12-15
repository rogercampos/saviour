require 'fileutils'

module Saviour
  class LocalStorage
    MissingPublicUrlPrefix = Class.new(StandardError)

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
      ::File.open(real_path(path)).read
    rescue Errno::ENOENT
      raise FileNotPresent, "Trying to read an unexisting path: #{path}"
    end

    def delete(path)
      ::File.delete(real_path(path))
      ensure_removed_empty_dir(path)
    rescue Errno::ENOENT
      raise FileNotPresent, "Trying to delete an unexisting path: #{path}"
    end

    def exists?(path)
      ::File.file?(real_path(path))
    end

    def public_url(path)
      raise(MissingPublicUrlPrefix, "You must provide a `public_url_prefix`") unless public_url_prefix
      ::File.join(public_url_prefix, path)
    end

    def cp(source_path, destination_path)
      FileUtils.cp(real_path(source_path), real_path(destination_path))
    rescue Errno::ENOENT
      raise FileNotPresent, "Trying to cp an unexisting path: #{source_path}"
    end

    def mv(source_path, destination_path)
      FileUtils.mv(real_path(source_path), real_path(destination_path))
    rescue Errno::ENOENT
      raise FileNotPresent, "Trying to mv an unexisting path: #{source_path}"
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

    def ensure_removed_empty_dir(path)
      basedir = ::File.dirname(path)
      return if basedir == "."

      while basedir != "/" && Dir.entries(real_path(basedir)) - [".", ".."] ==[]
        Dir.rmdir(real_path(basedir))
        basedir = ::File.dirname(basedir)
      end
    end
  end
end
