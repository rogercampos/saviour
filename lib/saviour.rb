require 'fileutils'
require 'digest/md5'
require 'active_support/concern'
require 'active_support/core_ext'
require 'active_support/core_ext/module/attribute_accessors'

require 'saviour/processors/digest'

require 'saviour/version'
require 'saviour/base_uploader'
require 'saviour/file'
require 'saviour/file_storage'
require 'saviour/config'
require 'saviour/string_source'
require 'saviour/url_source'

module Saviour
  extend ActiveSupport::Concern

  NoActiveRecordDetected = Class.new(StandardError)

  included do
    raise(NoActiveRecordDetected, "Error: ActiveRecord not detected in #{self}") unless self.ancestors.include?(ActiveRecord::Base)

    class_attribute(:__saviour_attached_files, :__saviour_validations)

    after_destroy do
      (self.class.__saviour_attached_files || {}).each do |column, versions|
        send(column).delete

        versions.each { |version|
          send(column, version).delete
        }
      end
    end

    after_save do
      (self.class.__saviour_attached_files || {}).each do |column, versions|
        if send(column).changed?
          Config.storage.delete(read_attribute(column)) if read_attribute(column)
          previous_content = send(column).send(:consumed_source)
          new_path = send(column).write
          update_column(column, new_path)

          versions.each do |version|
            Config.storage.delete(read_attribute("#{column}_#{version}")) if read_attribute("#{column}_#{version}")
            send(column, version).assign(StringSource.new(previous_content, "#{::File.basename(send(column).filename, ".*")}_#{version}#{::File.extname(send(column).filename)}"))
            new_path = send(column, version).write
            update_column("#{column}_#{version}", new_path)
          end
        end
      end
    end

    validate do
      (self.class.__saviour_validations || {}).each do |column, method_or_blocks|
        if send(column).changed?
          method_or_blocks.each do |method_or_block|
            if method_or_block.respond_to?(:call)
              instance_exec(send(column).send(:consumed_source), &method_or_block)
            else
              send(method_or_block, send(column).send(:consumed_source))
            end
          end
        end
      end
    end
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

