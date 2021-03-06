module Saviour
  module Model
    def self.included(klass)
      Integrator.new(klass, PersistenceLayer).setup!

      klass.class_eval do
        raise(NoActiveRecordDetected, "Error: ActiveRecord not detected in #{self}") unless self.ancestors.include?(ActiveRecord::Base)

        after_destroy { Saviour::LifeCycle.new(self, PersistenceLayer).delete! }
        after_update { Saviour::LifeCycle.new(self, PersistenceLayer).update! }
        after_create { Saviour::LifeCycle.new(self, PersistenceLayer).create! }
        validate { Saviour::Validator.new(self).validate! }
      end
    end

    def reload(*args)
      self.class.attached_files.each do |attach_as|
        instance_variable_set("@__uploader_#{attach_as}", nil)
      end
      super
    end

    def dup
      duped = super

      self.class.attached_files.each do |attach_as|
        duped[attach_as] = nil
        duped.instance_variable_set("@__uploader_#{attach_as}", send(attach_as).dup(duped))
        duped.instance_variable_set("@__uploader_#{attach_as}_was", nil)
      end

      duped
    end
  end
end