module Saviour
  class AttributeNameCalculator
    def initialize(attached_as, version = nil)
      @attached_as, @version = attached_as, version
    end

    def name
      if @version
        "#{@attached_as}_#{@version}"
      else
        @attached_as.to_s
      end
    end
  end
end