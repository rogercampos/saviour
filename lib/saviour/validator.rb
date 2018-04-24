module Saviour
  class Validator

    class AttachmentValidator
      def initialize(model, column, validations)
        @model = model
        @column = column
        @validations = validations
        @file = model.send(column)
      end

      def validate!
        @validations.each do |data|
          type = data[:type]
          method_or_block = data[:method_or_block]

          case type
          when :memory
            run_validation(method_or_block)
          when :file
            run_validation_as_file(method_or_block)
          end
        end

      ensure
        @source_as_file.close! if @source_as_file
      end

      private


      def source_type
        if @file.source.respond_to?(:path)
          :file
        else
          :stream
        end
      end

      def filename
        @filename ||= @file.filename_to_be_assigned
      end

      def source_as_memory
        @source_as_memory ||= @file.source_data
      end

      def source_as_file
        @source_as_file ||= begin
          f = Tempfile.new("")
          f.binmode

          if source_type == :file
            FileUtils.cp(@file.source.path, f.path)
          else
            ::File.binwrite(f.path, source_as_memory)
          end

          f
        end
      end

      def run_validation(method_or_block)
        opts = { attached_as: @column }

        if method_or_block.respond_to?(:call)
          if method_or_block.arity == 2
            @model.instance_exec(source_as_memory, filename, &method_or_block)
          else
            @model.instance_exec(source_as_memory, filename, opts, &method_or_block)
          end
        else
          if @model.method(method_or_block).arity == 2
            @model.send(method_or_block, source_as_memory, filename)
          else
            @model.send(method_or_block, source_as_memory, filename, opts)
          end
        end
      end

      def run_validation_as_file(method_or_block)
        opts = { attached_as: @column }

        if method_or_block.respond_to?(:call)
          if method_or_block.arity == 2
            @model.instance_exec(source_as_file, filename, &method_or_block)
          else
            @model.instance_exec(source_as_file, filename, opts, &method_or_block)
          end
        else
          if @model.method(method_or_block).arity == 2
            @model.send(method_or_block, source_as_file, filename)
          else
            @model.send(method_or_block, source_as_file, filename, opts)
          end
        end
      end
    end


    def initialize(model)
      raise(ConfigurationError, "Please provide an object compatible with Saviour.") unless model.class.respond_to?(:attached_files)
      @model = model
    end

    def validate!
      validations.each do |column, declared_validations|
        raise(ConfigurationError, "There is no attachment defined as '#{column}'") unless attached_files.include?(column)

        if @model.send(column).changed?
          AttachmentValidator.new(@model, column, declared_validations).validate!
        end
      end
    end

    def attached_files
      @model.class.attached_files
    end

    def validations
      @model.class.__saviour_validations || {}
    end
  end
end