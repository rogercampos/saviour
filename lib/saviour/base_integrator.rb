module Saviour
  class BaseIntegrator
    def initialize(klass)
      @klass = klass
    end

    def file_instantiator_hook(model, file_instance, attach_as, version)
      # noop
    end

    def attach_file_hook(klass, attach_as, uploader_klass)
      # noop
    end

    def setup!
      raise "You cannot include Saviour twice in the same class" if @klass.respond_to?(:attached_files)

      @klass.send :extend, ClassAttribute
      @klass.class_attribute :attached_files
      @klass.attached_files = {}

      a = self
      b = @klass

      @klass.define_singleton_method "attach_file" do |attach_as, uploader_klass|
        a.attach_file_hook(self, attach_as, uploader_klass)

        versions = uploader_klass.versions || []
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
    end
  end
end