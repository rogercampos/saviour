module Saviour
  module Uploader
    class StoreDirExtractor
      def initialize(uploader)
        @uploader = uploader
      end

      def store_dir_handler
        @store_dir_handler ||= @uploader.class.store_dirs.last
      end

      def store_dir
        @store_dir ||= begin
          if store_dir_handler
            if store_dir_handler.respond_to?(:call)
              @uploader.instance_eval(&store_dir_handler)
            else
              @uploader.send(store_dir_handler)
            end
          end
        end
      end
    end
  end
end