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
  class ModelHooks
    def initialize(model)
      @model = model
    end

    def delete!
      attached_files.each do |column, versions|
        @model.send(column).delete if @model.send(column).exists?
        versions.each { |version| @model.send(column, version).delete if @model.send(column, version).exists? }
      end
    end

    def save!
      attached_files.each do |column, versions|
        if @model.send(column).changed?
          name = column_name(column, nil)
          previous_content = @model.send(column).send(:consumed_source)

          Config.storage.delete(@model[name]) if @model[name] && @model.send(column).exists?
          upload_file(column, nil)

          versions.each do |version|
            name = column_name(column, version)

            Config.storage.delete(@model[name]) if @model[name] && @model.send(column, version).exists?
            @model.send(column, version).assign(StringSource.new(previous_content, version_filename(column, version)))
            upload_file(column, version)
          end
        end
      end
    end

    def validate!
      validations.each do |column, method_or_blocks|
        if @model.send(column).changed?
          method_or_blocks.each { |method_or_block| run_validation(column, method_or_block) }
        end
      end
    end

    def version_filename(column, version)
      "#{::File.basename(@model.send(column).filename, ".*")}_#{version}#{::File.extname(@model.send(column).filename)}"
    end

    def upload_file(column, version)
      new_path = @model.send(column, version).write
      @model.update_column(column_name(column, version), new_path)
    end

    def column_name(column, version)
      if version
        "#{column}_#{version}"
      else
        column
      end
    end

    def attached_files
      @model.class.__saviour_attached_files || {}
    end

    def run_validation(column, method_or_block)
      if method_or_block.respond_to?(:call)
        @model.instance_exec(@model.send(column).send(:consumed_source), &method_or_block)
      else
        @model.send(method_or_block, @model.send(column).send(:consumed_source))
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

  module ClassMethods
    def attach_file(column, uploader_klass, opts = {})
      self.__saviour_attached_files ||= {}

      versions = opts.fetch(:versions, [])

      ([column] + versions.map { |x| "#{column}_#{x}" }).each do |column_name|
        unless self.column_names.include?(column_name.to_s)
          raise RuntimeError, "#{self} must have a database string column named '#{column_name}'"
        end
      end

      define_method(column) do |version = nil|
        instance_variable_get("@__uploader_#{version}_#{column}") ||
            instance_variable_set("@__uploader_#{version}_#{column}", ::Saviour::File.new(uploader_klass, self, column, version))
      end

      define_method("#{column}=") do |value|
        send(column).assign(value)
      end

      define_method("#{column}_changed?") do
        send(column).changed?
      end

      self.__saviour_attached_files[column] ||= []
      self.__saviour_attached_files[column] += versions
    end

    def attach_validation(column, method_name = nil, &block)
      self.__saviour_validations ||= Hash.new { [] }
      self.__saviour_validations[column] += [method_name || block]
    end
  end
end

