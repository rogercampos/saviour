module Saviour
  class Validator
    def initialize(model)
      raise(ConfigurationError, "Please provide an object compatible with Saviour.") unless model.class.respond_to?(:attached_files)

      @model = model
    end

    def validate!
      validations.each do |column, method_or_blocks|
        raise(ConfigurationError, "There is no attachment defined as '#{column}'") unless attached_files.include?(column)
        if @model.send(column).changed?
          method_or_blocks.each { |method_or_block| run_validation(column, method_or_block) }
        end
      end
    end

    private

    def run_validation(column, method_or_block)
      data = @model.send(column).source_data
      filename = @model.send(column).filename_to_be_assigned
      opts = { attached_as: column }

      if method_or_block.respond_to?(:call)
        if method_or_block.arity == 2
          @model.instance_exec(data, filename, &method_or_block)
        else
          @model.instance_exec(data, filename, opts, &method_or_block)
        end
      else
        if @model.method(method_or_block).arity == 2
          @model.send(method_or_block, data, filename)
        else
          @model.send(method_or_block, data, filename, opts)
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