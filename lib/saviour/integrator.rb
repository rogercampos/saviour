module Saviour
  class Integrator
    def initialize(klass, persistence_klass)
      @klass = klass
      @persistence_klass = persistence_klass
    end

    def setup!
      raise "You cannot include Saviour twice in the same class" if @klass.respond_to?(:attached_files)

      @klass.class_attribute :attached_files
      @klass.attached_files = []
      @klass.class_attribute :attached_followers_per_leader
      @klass.attached_followers_per_leader = {}

      klass = @klass
      persistence_klass = @persistence_klass

      @klass.define_singleton_method "attach_file" do |attach_as, *maybe_uploader_klass, **opts, &block|
        klass.attached_files.push(attach_as)
        uploader_klass = maybe_uploader_klass[0]

        if opts[:follow]
          klass.attached_followers_per_leader[opts[:follow]] ||= []
          klass.attached_followers_per_leader[opts[:follow]].push(attach_as)
        end

        if uploader_klass.nil? && block.nil?
          raise ArgumentError, "you must provide either an UploaderClass or a block to define it."
        end

        mod = Module.new do
          define_method(attach_as) do
            instance_variable_get("@__uploader_#{attach_as}") || begin
              uploader_klass = Class.new(Saviour::BaseUploader, &block) if block
              new_file = ::Saviour::File.new(uploader_klass, self, attach_as)

              layer = persistence_klass.new(self)
              new_file.set_path!(layer.read(attach_as))

              instance_variable_set("@__uploader_#{attach_as}", new_file)
            end
          end

          define_method("#{attach_as}=") do |value|
            send(attach_as).assign(value)
          end

          define_method("#{attach_as}_changed?") do
            send(attach_as).changed?
          end
        end

        klass.include mod
      end

      @klass.class_attribute :__saviour_validations

      @klass.define_singleton_method("attach_validation") do |attach_as, method_name = nil, &block|
        klass.__saviour_validations ||= Hash.new { [] }
        klass.__saviour_validations[attach_as] += [method_name || block]
      end
    end
  end
end