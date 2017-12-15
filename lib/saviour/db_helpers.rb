# frozen_string_literal: true

module Saviour
  module DbHelpers
    NotInTransaction = Class.new(StandardError)

    class CommitDummy
      def initialize(block)
        @block = block
      end

      def rolledback!(*)
        close_transaction
      end

      def close_transaction(*)
      end

      def before_committed!(*)
      end

      def committed!(*)
        @block.call
      end
    end

    class RollbackDummy
      def initialize(block)
        @block = block
      end

      def rolledback!(*)
        @block.call
        close_transaction
      end

      def close_transaction(*)
      end

      def before_committed!(*)
      end

      def committed!(*)
      end
    end


    class << self

      def run_after_commit(&block)
        unless ActiveRecord::Base.connection.current_transaction.open?
          raise NotInTransaction, 'Trying to use `run_after_commit` but no transaction is currently open.'
        end

        dummy = CommitDummy.new(block)
        ActiveRecord::Base.connection.add_transaction_record(dummy)
      end

      def run_after_rollback(&block)
        unless ActiveRecord::Base.connection.current_transaction.open?
          raise NotInTransaction, 'Trying to use `run_after_commit` but no transaction is currently open.'
        end

        dummy = RollbackDummy.new(block)
        ActiveRecord::Base.connection.add_transaction_record(dummy)
      end
    end
  end
end
