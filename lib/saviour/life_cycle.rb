module Saviour
  class LifeCycle
    def initialize(model, persistence_klass = nil)
      raise "Please provide an object compatible with Saviour." unless model.class.respond_to?(:attached_files)

      @persistence_klass = persistence_klass
      @model = model
    end

    def delete!
      attached_files.each do |column|
        @model.send(column).delete if @model.send(column).exists?
      end
    end

    def save!
      attached_files.each do |column|
        base_file_changed = @model.send(column).changed?

        upload_file(column) if base_file_changed
      end
    end


    private


    def upload_file(column)
      persistence_layer = @persistence_klass.new(@model) if @persistence_klass
      current_path = persistence_layer.read(column) if persistence_layer

      Config.storage.delete(current_path) if current_path

      new_path = @model.send(column).write
      persistence_layer.write(column, new_path) if persistence_layer
    end

    def attached_files
      @model.class.attached_files
    end
  end
end