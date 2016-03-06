module Saviour
  module Uploader
    class StoreDirExtractor
      def initialize(uploader)
        @uploader = uploader
      end

      def candidate_store_dirs
        @candidate_store_dirs ||= @uploader.class.store_dirs
      end

      def versioned_store_dirs?
        candidate_store_dirs.any? { |x| x.versioned? && x.version == @uploader.version_name }
      end

      def versioned_store_dir
        candidate_store_dirs.select { |x| x.versioned? && x.version == @uploader.version_name }.last if versioned_store_dirs?
      end

      def non_versioned_store_dir
        candidate_store_dirs.select { |x| !x.versioned? }.last
      end

      def store_dir_handler
        @store_dir_handler ||= versioned_store_dir || non_versioned_store_dir
      end

      def store_dir
        @store_dir ||= begin
          if store_dir_handler
            if store_dir_handler.block?
              @uploader.instance_eval(&store_dir_handler.method_or_block)
            else
              @uploader.send(store_dir_handler.method_or_block)
            end
          end
        end
      end
    end
  end
end