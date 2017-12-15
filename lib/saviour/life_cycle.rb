module Saviour
  class LifeCycle
    def initialize(model, persistence_klass)
      raise ConfigurationError, "Please provide an object compatible with Saviour." unless model.class.respond_to?(:attached_files)

      @persistence_klass = persistence_klass
      @model = model
    end

    def delete!
      DbHelpers.run_after_commit do
        attached_files.each do |column|
          @model.send(column).delete
        end
      end
    end

    def create!
      attached_files.each do |column|
        next unless @model.send(column).changed?

        persistence_layer = @persistence_klass.new(@model)
        new_path = @model.send(column).write

        if new_path
          persistence_layer.write(column, new_path)

          DbHelpers.run_after_rollback do
            Config.storage.delete(new_path)
          end
        end
      end
    end

    def update!
      attached_files.each do |column|
        next unless @model.send(column).changed?

        update_file(column)
      end
    end


    private


    def update_file(column)
      persistence_layer = @persistence_klass.new(@model)
      current_path = persistence_layer.read(column)
      dup_temp_path = SecureRandom.hex

      dup_file = proc do
        Config.storage.cp current_path, dup_temp_path

        DbHelpers.run_after_commit do
          Config.storage.delete dup_temp_path
        end

        DbHelpers.run_after_rollback do
          Config.storage.mv dup_temp_path, current_path
        end
      end

      new_path = @model.send(column).write(
        before_write: ->(path) { dup_file.call if current_path == path }
      )

      if new_path
        persistence_layer.write(column, new_path)

        if current_path && current_path != new_path
          DbHelpers.run_after_commit do
            Config.storage.delete(current_path)
          end
        end

        # Delete the newly uploaded file only if it's an update in a different path
        if current_path.nil? || current_path != new_path
          DbHelpers.run_after_rollback do
            Config.storage.delete(new_path)
          end
        end
      end
    end

    def attached_files
      @model.class.attached_files
    end
  end
end