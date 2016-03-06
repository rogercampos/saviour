module Saviour
  module Uploader
    class Element
      attr_reader :version, :method_or_block

      def initialize(version, method_or_block)
        @version, @method_or_block = version, method_or_block
      end

      def versioned?
        !!@version
      end

      def block?
        @method_or_block.respond_to?(:call)
      end
    end
  end
end