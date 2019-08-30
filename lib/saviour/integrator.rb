module Saviour
  class Integrator
    def initialize(klass, persistence_klass)
      @klass = klass
      @persistence_klass = persistence_klass
    end

    def setup!
      raise(ConfigurationError, "You cannot include Saviour::Model twice in the same class") if @klass.respond_to?(:attached_files)

      @klass.class_attribute :attached_files
      @klass.attached_files = []
      @klass.class_attribute :followers_per_leader_config
      @klass.followers_per_leader_config = {}
      @klass.class_attribute :uploader_classes
      @klass.uploader_classes = {}

      persistence_klass = @persistence_klass

      @klass.define_singleton_method "attach_file" do |attach_as, *maybe_uploader_klass, **opts, &block|
        self.attached_files += [attach_as]

        uploader_klass = maybe_uploader_klass[0]

        if opts[:follow]
          dependent = opts[:dependent]

          if dependent.nil? || ![:destroy, :ignore].include?(dependent)
            raise(ConfigurationError, "You must specify a :dependent option when using :follow. Use either :destroy or :ignore")
          end

          self.followers_per_leader_config = self.followers_per_leader_config.dup
          self.followers_per_leader_config[opts[:follow]] ||= []
          self.followers_per_leader_config[opts[:follow]].push({ attachment: attach_as, dependent: dependent })
        end

        if uploader_klass.nil? && block.nil?
          raise ConfigurationError, "you must provide either an UploaderClass or a block to define it."
        end

        uploader_klass = Class.new(Saviour::BaseUploader, &block) if block

        self.uploader_classes[attach_as] = uploader_klass

        mod = Module.new do
          define_method(attach_as) do
            instance_variable_get("@__uploader_#{attach_as}") || begin
              layer = persistence_klass.new(self)
              new_file = ::Saviour::File.new(uploader_klass, self, attach_as, layer.read(attach_as))

              instance_variable_set("@__uploader_#{attach_as}", new_file)
            end
          end

          define_method("#{attach_as}=") do |value|
            send(attach_as).assign(value)
          end

          define_method("#{attach_as}?") do
            send(attach_as).present?
          end

          define_method("#{attach_as}_was") do
            instance_variable_get("@__uploader_#{attach_as}_was")
          end

          define_method("#{attach_as}_changed?") do
            send(attach_as).changed?
          end

          define_method(:changed_attributes) do
            if send("#{attach_as}_changed?")
              super().merge(attach_as => send("#{attach_as}_was"))
            else
              super()
            end
          end

          define_method(:changes) do
            if send("#{attach_as}_changed?")
              super().merge(attach_as => send("#{attach_as}_change"))
            else
              super()
            end
          end

          define_method(:changed) do
            if ActiveRecord::VERSION::MAJOR == 6 && send("#{attach_as}_changed?")
              super() + [attach_as.to_s]
            else
              super()
            end
          end

          define_method(:changed?) do
            if ActiveRecord::VERSION::MAJOR == 6
              send("#{attach_as}_changed?") || super()
            else
              super()
            end
          end

          define_method("#{attach_as}_change") do
            [send("#{attach_as}_was"), send(attach_as)]
          end

          define_method("remove_#{attach_as}!") do |dependent: nil|
            if !dependent.nil? && ![:destroy, :ignore].include?(dependent)
              raise ArgumentError, ":dependent option must be either :destroy or :ignore"
            end

            layer = persistence_klass.new(self)

            attachment_remover = proc do |attach_as|
              layer.write(attach_as, nil)
              deletion_path = send(attach_as).persisted_path
              send(attach_as).delete

              work = proc do
                file = send(attach_as)
                file.uploader.storage.delete(deletion_path) if deletion_path && file.persisted_path.nil?
              end

              if ActiveRecord::Base.connection.current_transaction.open?
                DbHelpers.run_after_commit &work
              else
                work.call
              end
            end

            attachment_remover.call(attach_as)

            (self.class.followers_per_leader_config[attach_as] || []).each do |follower|
              dependent_option = dependent || follower[:dependent]
              next if dependent_option == :ignore || send(follower[:attachment]).changed?

              attachment_remover.call(follower[:attachment])
            end
          end
        end

        self.include mod
      end

      @klass.define_singleton_method("attached_followers_per_leader") do
        self.followers_per_leader_config.map do |leader, followers|
          [leader, followers.map { |data| data[:attachment] }]
        end.to_h
      end

      @klass.class_attribute :__saviour_validations
      @klass.__saviour_validations = Hash.new { [] }

      @klass.define_singleton_method("attach_validation") do |attach_as, method_name = nil, &block|
        self.__saviour_validations = self.__saviour_validations.dup
        self.__saviour_validations[attach_as] += [{ method_or_block: method_name || block, type: :memory }]
      end

      @klass.define_singleton_method("attach_validation_with_file") do |attach_as, method_name = nil, &block|
        self.__saviour_validations = self.__saviour_validations.dup
        self.__saviour_validations[attach_as] += [{ method_or_block: method_name || block, type: :file }]
      end
    end
  end
end
