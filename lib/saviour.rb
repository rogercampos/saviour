require 'fileutils'
require 'digest/md5'
require 'active_support/concern'
require 'active_support/core_ext'
require 'active_support/core_ext/module/attribute_accessors'
require 'fog/aws'

require 'saviour/processors/digest'

require 'saviour/version'
require 'saviour/base_uploader'
require 'saviour/file'
require 'saviour/local_storage'
require 'saviour/s3_storage'
require 'saviour/config'
require 'saviour/string_source'
require 'saviour/url_source'

module Saviour
  class ColumnNamer
    def initialize(attached_as, version = nil)
      @attached_as, @version = attached_as, version
    end

    def name
      if @version
        "#{@attached_as}_#{@version}"
      else
        @attached_as.to_s
      end
    end
  end

  class ModelHooks
    def initialize(model)
      @model = model
    end

    def delete!
      attached_files.each do |column, versions|
        (versions + [nil]).each { |version| @model.send(column, version).delete if @model.send(column, version).exists? }
      end
    end

    def save!
      attached_files.each do |column, versions|
        base_file_changed = @model.send(column).changed?
        original_content = @model.send(column).source_data if base_file_changed

        versions.each do |version|
          if @model.send(column, version).changed?
            upload_file(column, version)
          elsif base_file_changed
            @model.send(column, version).assign(StringSource.new(original_content, default_version_filename(column, version)))
            upload_file(column, version)
          end
        end

        upload_file(column, nil) if base_file_changed
      end
    end

    def validate!
      validations.each do |column, method_or_blocks|
        (attached_files[column] + [nil]).each do |version|
          if @model.send(column, version).changed?
            method_or_blocks.each { |method_or_block| run_validation(column, version, method_or_block) }
          end
        end
      end
    end

    def default_version_filename(column, version)
      filename = @model.send(column).filename_to_be_assigned
      "#{::File.basename(filename, ".*")}_#{version}#{::File.extname(filename)}"
    end

    def upload_file(column, version)
      name = ColumnNamer.new(column, version).name
      Config.storage.delete(@model.read_attribute(name)) if @model.read_attribute(name)
      new_path = @model.send(column, version).write
      @model.update_column(name, new_path)
    end

    def attached_files
      @model.class.__saviour_attached_files || {}
    end

    def run_validation(column, version, method_or_block)
      data = @model.send(column, version).source_data
      filename = @model.send(column, version).filename_to_be_assigned
      opts = {attached_as: column, version: version}

      if method_or_block.respond_to?(:call)
        if method_or_block.arity == 2
          @model.instance_exec(data, filename, &method_or_block)
        else
          @model.instance_exec(data, filename, opts, &method_or_block)
        end
      else
        if @model.method(method_or_block).arity == 2
          @model.send(method_or_block, data, filename)
        else
          @model.send(method_or_block, data, filename, opts)
        end
      end
    end

    def validations
      @model.class.__saviour_validations || {}
    end
  end

  extend ActiveSupport::Concern

  NoActiveRecordDetected = Class.new(StandardError)

  included do
    raise(NoActiveRecordDetected, "Error: ActiveRecord not detected in #{self}") unless self.ancestors.include?(ActiveRecord::Base)

    class_attribute(:__saviour_attached_files, :__saviour_validations)

    after_destroy { ModelHooks.new(self).delete! }
    after_save { ModelHooks.new(self).save! }
    validate { ModelHooks.new(self).validate! }
  end

  def reload
    self.class.__saviour_attached_files.each do |attach_as, versions|
      (versions + [nil]).each { |version| instance_variable_set("@__uploader_#{version}_#{attach_as}", nil) }
    end
    super
  end

  module ClassMethods
    def attach_file(attach_as, uploader_klass)
      self.__saviour_attached_files ||= {}
      versions = uploader_klass.versions || []

      ([nil] + versions).each do |version|
        column_name = ColumnNamer.new(attach_as, version).name

        if self.table_exists? && !self.column_names.include?(column_name.to_s)
          raise RuntimeError, "#{self} must have a database string column named '#{column_name}'"
        end
      end

      define_method(attach_as) do |version = nil|
        instance_variable_get("@__uploader_#{version}_#{attach_as}") ||
            instance_variable_set("@__uploader_#{version}_#{attach_as}", ::Saviour::File.new(uploader_klass, self, attach_as, version))
      end

      define_method("#{attach_as}=") do |value|
        send(attach_as).assign(value)
      end

      define_method("#{attach_as}_changed?") do
        send(attach_as).changed?
      end

      self.__saviour_attached_files[attach_as] ||= []
      self.__saviour_attached_files[attach_as] += versions
    end

    def attach_validation(attach_as, method_name = nil, &block)
      self.__saviour_validations ||= Hash.new { [] }
      self.__saviour_validations[attach_as] += [method_name || block]
    end
  end
end
