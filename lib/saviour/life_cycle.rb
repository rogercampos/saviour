module Saviour
  class LifeCycle
    def initialize(model, persistence_klass = nil)
      raise "Please provide an object compatible with Saviour." unless model.class.respond_to?(:attached_files)

      @persistence_klass = persistence_klass
      @model = model
    end

    def delete!
      attached_files.each do |column, versions|
        (versions + [nil]).each { |version| @model.send(column, version).delete if @model.send(column, version).exists? }
      end
    end

    def save!
      attached_files.each do |column, versions|
        base_file_changed = @model.send(column).changed?
        original_content = @model.send(column).source_data if base_file_changed

        versions.each do |version|
          if @model.send(column, version).changed?
            upload_file(column, version)
          elsif base_file_changed
            @model.send(column, version).assign(StringSource.new(original_content, default_version_filename(column, version)))
            upload_file(column, version)
          end
        end

        upload_file(column, nil) if base_file_changed
      end
    end


    private

    def default_version_filename(column, version)
      filename = @model.send(column).filename_to_be_assigned
      "#{::File.basename(filename, ".*")}_#{version}#{::File.extname(filename)}"
    end

    def upload_file(column, version)
      name = AttributeNameCalculator.new(column, version).name
      persistence_layer = @persistence_klass.new(@model) if @persistence_klass
      current_path = persistence_layer.read(name) if persistence_layer

      Config.storage.delete(current_path) if current_path

      new_path = @model.send(column, version).write
      persistence_layer.write(name, new_path) if persistence_layer
    end

    def attached_files
      @model.class.attached_files || {}
    end
  end
end