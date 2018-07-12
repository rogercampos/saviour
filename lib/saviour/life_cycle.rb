module Saviour
  class LifeCycle
    class FileCreator
      def initialize(current_path, file, column, connection)
        @file = file
        @column = column
        @current_path = current_path
        @connection = connection
      end

      def upload
        @new_path = @file.write

        return unless @new_path

        DbHelpers.run_after_rollback(@connection) do
          Config.storage.delete(@new_path)
        end

        [@column, @new_path]
      end

      def uploader
        @file.uploader
      end
    end

    class FileUpdater
      def initialize(current_path, file, column, connection)
        @file = file
        @column = column
        @current_path = current_path
        @connection = connection
      end

      def upload
        dup_temp_path = SecureRandom.hex

        dup_file = proc do
          Config.storage.cp @current_path, dup_temp_path

          DbHelpers.run_after_commit(@connection) do
            Config.storage.delete dup_temp_path
          end

          DbHelpers.run_after_rollback(@connection) do
            Config.storage.mv dup_temp_path, @current_path
          end
        end

        @new_path = @file.write(
          before_write: ->(path) { dup_file.call if @current_path == path }
        )

        return unless @new_path

        if @current_path && @current_path != @new_path
          DbHelpers.run_after_commit(@connection) do
            Config.storage.delete(@current_path)
          end
        end

        # Delete the newly uploaded file only if it's an update in a different path
        if @current_path.nil? || @current_path != @new_path
          DbHelpers.run_after_rollback(@connection) do
            Config.storage.delete(@new_path)
          end
        end

        [@column, @new_path]
      end

      def uploader
        @file.uploader
      end
    end

    def initialize(model, persistence_klass)
      raise ConfigurationError, "Please provide an object compatible with Saviour." unless model.class.respond_to?(:attached_files)

      @persistence_klass = persistence_klass
      @model = model
    end

    def delete!
      DbHelpers.run_after_commit do
        pool = Concurrent::FixedThreadPool.new(Saviour::Config.concurrent_workers)

        futures = attached_files.map do |column|
          Concurrent::Future.execute(executor: pool) {
            @model.send(column).delete
          }
        end

        ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
          futures.each do |future|
            future.value
            raise(future.reason) if future.rejected?
          end
        end

        pool.shutdown
        pool.wait_for_termination
      end
    end

    def create!
      process_upload(FileCreator)
    end

    def update!
      process_upload(FileUpdater)
    end

    private

    def process_upload(klass)
      persistence_layer = @persistence_klass.new(@model)

      uploaders = attached_files.map do |column|
        next unless @model.send(column).changed?

        klass.new(
          persistence_layer.read(column),
          @model.send(column),
          column,
          ActiveRecord::Base.connection
        )
      end.compact

      pool = Concurrent::FixedThreadPool.new(Saviour::Config.concurrent_workers)
      futures = uploaders.map { |uploader|
        Concurrent::Future.execute(executor: pool) {
          if defined?(Rails)
            Rails.application.executor.wrap { uploader.upload }
          else
            uploader.upload
          end
        }
      }

      result = ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
        futures.map do |x|
          x.value.tap do
            raise(x.reason) if x.rejected?
          end
        end.compact
      end

      pool.shutdown
      pool.wait_for_termination

      attrs = result.to_h

      uploaders.map(&:uploader).select { |x| x.class.after_upload_hooks.any? }.each do |uploader|
        uploader.class.after_upload_hooks.each do |hook|
          uploader.instance_exec(uploader.stashed, &hook)
        end
      end

      persistence_layer.write_attrs(attrs) if attrs.length > 0
    end

    def attached_files
      @model.class.attached_files
    end
  end
end