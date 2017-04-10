module Saviour
  class PersistenceLayer
    def initialize(model)
      @model = model
    end

    def read(attr)
      @model.read_attribute(attr)
    end

    def write(attr, value)
      @model.update_columns(attr => value)
    end

    def persisted?
      @model.persisted? || @model.destroyed?
    end
  end
end