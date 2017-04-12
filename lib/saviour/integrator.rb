module Saviour
  class Integrator
    def initialize(klass, persistence_klass)
      @klass = klass
      @persistence_klass = persistence_klass
    end

    def file_instantiator_hook(model, file_instance, attach_as, version)
      layer = @persistence_klass.new(model)
      file_instance.set_path!(layer.read(Saviour::AttributeNameCalculator.new(attach_as, version).name)) if layer.persisted?
    end

    def attach_file_hook(klass, attach_as, uploader_klass)
      versions = uploader_klass.versions.keys

      ([nil] + versions).each do |version|
        column_name = Saviour::AttributeNameCalculator.new(attach_as, version).name

        if klass.table_exists? && !klass.column_names.include?(column_name.to_s)
          raise RuntimeError, "#{klass} must have a database string column named '#{column_name}'"
        end
      end
    end

    def setup!
      raise "You cannot include Saviour twice in the same class" if @klass.respond_to?(:attached_files)

      @klass.class_attribute :attached_files
      @klass.attached_files = {}

      a = self
      b = @klass

      @klass.define_singleton_method "attach_file" do |attach_as, uploader_klass|
        a.attach_file_hook(self, attach_as, uploader_klass)

        versions = uploader_klass.versions.keys
        b.attached_files[attach_as] ||= []
        b.attached_files[attach_as] += versions

        b.class_eval do
          define_method(attach_as) do |version = nil|
            instance_variable_get("@__uploader_#{version}_#{attach_as}") || begin
              new_file = ::Saviour::File.new(uploader_klass, self, attach_as, version)
              a.file_instantiator_hook(self, new_file, attach_as, version)

              instance_variable_set("@__uploader_#{version}_#{attach_as}", new_file)
            end
          end

          define_method("#{attach_as}=") do |value|
            send(attach_as).assign(value)
          end

          define_method("#{attach_as}_changed?") do
            send(attach_as).changed?
          end
        end
      end

      @klass.class_attribute :__saviour_validations

      class << @klass
        def attach_validation(attach_as, method_name = nil, &block)
          self.__saviour_validations ||= Hash.new { [] }
          self.__saviour_validations[attach_as] += [method_name || block]
        end
      end
    end
  end
end