module Saviour
  module BasicModel
    def self.included(klass)
      BaseIntegrator.new(klass).setup!
    end
  end
end