module Saviour
  NoActiveRecordDetected = Class.new(StandardError)

  module Model
    def self.included(klass)
      Integrator.new(klass, PersistenceLayer).setup!

      klass.class_eval do
        raise(NoActiveRecordDetected, "Error: ActiveRecord not detected in #{self}") unless self.ancestors.include?(ActiveRecord::Base)

        after_destroy { Saviour::LifeCycle.new(self, PersistenceLayer).delete! }
        after_save { Saviour::LifeCycle.new(self, PersistenceLayer).save! }
        validate { Saviour::Validator.new(self).validate! }
      end
    end

    def reload
      self.class.attached_files.each do |attach_as, versions|
        (versions + [nil]).each { |version| instance_variable_set("@__uploader_#{version}_#{attach_as}", nil) }
      end
      super
    end
  end
end